import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:naliv_delivery/core/theme_controller.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/browser_history.dart';
import 'package:naliv_delivery/utils/browser_route_history_observer.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/services/onesignal_push_provider.dart';
import 'package:naliv_delivery/services/telemetry_consent_service.dart';
import 'package:naliv_delivery/widgets/app_entry_gate.dart';
import 'package:naliv_delivery/features/faq/ui/faq_page.dart';
import 'package:naliv_delivery/features/faq/models/faq.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:naliv_delivery/utils/app_navigator.dart';
import 'widgets/cart_persistence_notice.dart';
import 'widgets/app_loading_screen.dart';
import 'widgets/app_loading_screen_web_stub.dart'
    if (dart.library.js_interop) 'widgets/app_loading_screen_web_real.dart';
import 'widgets/app_update_notice.dart';
import 'widgets/authentication_wrapper.dart';
import 'features/support/ui/city_contacts_sheet.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
final BrowserRouteHistoryObserver browserRouteHistoryObserver =
    BrowserRouteHistoryObserver();

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      NotificationService.installProvider(OneSignalPushProvider());
      // Request portrait where supported. Android 16 ignores this on large
      // displays (smallest width >= 600 dp), which must remain responsive.
      //
      // Web is excluded on purpose: `screen.orientation.lock()` rejects there unless the document
      // is fullscreen, and awaiting that rejection aborted main() before runApp — a blank page.
      // Verified against a console trace showing DomScreenOrientation.lock -> completeError.
      if (!kIsWeb) {
        await SystemChrome.setPreferredOrientations(
          const [DeviceOrientation.portraitUp],
        );
      }
      final bootstrap = await Future.wait<Object?>([
        PackageInfo.fromPlatform(),
        TelemetryConsentService.loadConsent(),
      ]);
      final packageInfo = bootstrap[0] as PackageInfo;

      await TelemetryConsentService.initialize(
        startReporting: () => SentryFlutter.init((options) {
          options.dsn =
              'https://d19c02e97e5b55f26c69d3cbd7ad8394@o4510957798883328.ingest.us.sentry.io/4511133765271552';
          options.environment = kReleaseMode ? 'production' : 'development';
          options.release =
              '${packageInfo.packageName}@${packageInfo.version}+${packageInfo.buildNumber}';
          options.tracesSampleRate = 0;
          options.enableAutoSessionTracking = false;
          options.sendDefaultPii = false;
          options.sendClientReports = false;
          options.beforeSend = (event, hint) =>
              TelemetryConsentService.cachedConsent ? event : null;
          options.beforeSendTransaction = (event, hint) => null;
          if (kIsWeb) {
            // SDK 9's JS bridge omits the consent hook and client-report option.
            // Keep Flutter error integrations, but use Dart's gated transport.
            options.autoInitializeNativeSdk = false;
            options.transport = SentryOptions().transport;
          }
        }),
      );
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CartProvider()),
            ChangeNotifierProvider(create: (_) => BusinessProvider()),
            ChangeNotifierProvider(create: (_) => LikedItemsProvider()),
            ChangeNotifierProvider(create: (_) => ThemeController()..load()),
          ],
          child: isHtmlSplashManaged()
              ? const Main()
              : const AppLaunchIntro(child: Main()),
        ),
      );
    },
    (error, stack) async {
      await Sentry.captureException(error, stackTrace: stack);
    },
  );
}

class Main extends StatefulWidget {
  const Main({super.key, this.contactLauncher});

  final Future<bool> Function(Uri)? contactLauncher;

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> with WidgetsBindingObserver {
  final _admissionKey = GlobalKey<NavigatorState>();
  bool _admitted = false;
  late String _pendingRoute = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  @override
  void initState() {
    super.initState();
    browserHistoryEnableExitWarning();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    browserHistoryDisableExitWarning();
    super.dispose();
  }

  void _admit() {
    if (mounted && !_admitted) setState(() => _admitted = true);
  }

  Future<bool> _platformRoute(String route) async {
    if (route == FaqPage.routeName) {
      _pendingRoute = route;
      final navigator = _admitted ? AppNavigator.key.currentState : null;
      if (navigator != null) unawaited(navigator.pushNamed<void>(route));
    }
    return true;
  }

  @override
  Future<bool> didPushRoute(String route) => _platformRoute(route);

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) =>
      _platformRoute(routeInformation.uri.path);

  Route<void>? _route(RouteSettings settings) {
    if (settings.name == '/') {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => _admitted
            ? const AppUpdateNotice(child: AuthenticationWrapper())
            : AppEntryGate(onAdmitted: _admit),
      );
    }
    if (_admitted && settings.name == FaqPage.routeName) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => FaqPage(
          initialSection: settings.arguments is FaqSection
              ? settings.arguments as FaqSection : null,
        ),
      );
    }
    return null;
  }

  List<Route<dynamic>> _initialRoutes(String _) => [
    _route(const RouteSettings(name: '/'))!,
    if (_admitted && _pendingRoute == FaqPage.routeName)
      _route(const RouteSettings(name: FaqPage.routeName))!,
  ];
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _admitted ? AppNavigator.key : _admissionKey,
      navigatorObservers: _admitted
          ? [browserRouteHistoryObserver, routeObserver, SentryNavigatorObserver()]
          : const [],
      builder: (context, child) => !_admitted
          ? child!
          : CityContactsLauncherScope(
              launch: widget.contactLauncher,
              child: _AdmittedApp(
                child: CartPersistenceNotice(
                  navigatorKey: AppNavigator.key,
                  child: child!,
                ),
              ),
            ),
      title: "Градусы24",
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en')],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // OS default with the user's override from the sidebar / profile switch.
      themeMode: context.watch<ThemeController>().mode,
      debugShowCheckedModeBanner: false,
      // Only the admission navigator exists before legal/city completion.
      initialRoute: '/',
      onGenerateInitialRoutes: _initialRoutes,
      onGenerateRoute: _route,
    );
  }
}

class _AdmittedApp extends StatefulWidget {
  const _AdmittedApp({required this.child});

  final Widget child;

  @override
  State<_AdmittedApp> createState() => _AdmittedAppState();
}

class _AdmittedAppState extends State<_AdmittedApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CartProvider>().loadCart();
      unawaited(
        NotificationService.instance.initialize().catchError(
              (Object error) =>
                  debugPrint('Push initialization unavailable: $error'),
            ),
      );
    });
  }


  @override
  Widget build(BuildContext context) => widget.child;
}
