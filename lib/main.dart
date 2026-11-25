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
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
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
import 'features/home/age_confirmation_session.dart';
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
        // Pre-warms the liquid-glass shaders alongside the other bootstrap
        // work so the first frosted surface never renders a fallback frame.
        LiquidGlassWidgets.initialize(),
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
        LiquidGlassWidgets.wrap(
          // Glass brightness follows the app's ThemeMode (and the user's
          // in-app theme switch), not just the OS setting.
          brightnessResolver: Theme.maybeBrightnessOf,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CartProvider()),
              ChangeNotifierProvider(create: (_) => BusinessProvider()),
              ChangeNotifierProvider(create: (_) => LikedItemsProvider()),
              ChangeNotifierProvider(
                  create: (_) => ThemeController()..load()),
            ],
            child: isHtmlSplashManaged()
                ? const Main()
                : const AppLaunchIntro(child: Main()),
          ),
        ),
      );
    },
    (error, stack) async {
      await Sentry.captureException(error, stackTrace: stack);
    },
  );
}

class Main extends StatefulWidget {
  const Main({super.key, this.contactLauncher, this.ageConfirmation});

  final Future<bool> Function(Uri)? contactLauncher;
  final AgeConfirmationSession? ageConfirmation;

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> with WidgetsBindingObserver {
  final _admissionKey = GlobalKey<NavigatorState>();
  late final AgeConfirmationSession _ageConfirmation =
      widget.ageConfirmation ?? AgeConfirmationSession.currentRun;
  bool _admitted = false;
  late bool _pendingFaq =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName ==
          FaqPage.routeName;

  @override
  void initState() {
    super.initState();
    _ageConfirmation.addListener(_schedulePendingFaq);
    browserHistoryEnableExitWarning();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _ageConfirmation.removeListener(_schedulePendingFaq);
    WidgetsBinding.instance.removeObserver(this);
    browserHistoryDisableExitWarning();
    super.dispose();
  }

  void _admit() {
    if (!mounted || _admitted) return;
    setState(() => _admitted = true);
    _schedulePendingFaq();
  }

  void _schedulePendingFaq() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingFaq());
  }

  void _openPendingFaq() {
    if (!mounted ||
        !_admitted ||
        !_ageConfirmation.isConfirmed ||
        !_pendingFaq) {
      return;
    }
    final navigator = AppNavigator.key.currentState;
    if (navigator == null) return;
    _pendingFaq = false;
    unawaited(navigator.pushNamed<void>(FaqPage.routeName));
  }

  Future<bool> _platformRoute(String route) async {
    if (route == FaqPage.routeName) {
      _pendingFaq = true;
      _openPendingFaq();
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
            ? ListenableBuilder(
                listenable: _ageConfirmation,
                child: const AuthenticationWrapper(),
                builder: (context, child) => AppUpdateNotice(
                  enabled: _ageConfirmation.isConfirmed,
                  child: child!,
                ),
              )
            : AppEntryGate(onAdmitted: _admit),
      );
    }
    if (_admitted &&
        _ageConfirmation.isConfirmed &&
        settings.name == FaqPage.routeName) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => FaqPage(
          initialSection: settings.arguments is FaqSection
              ? settings.arguments as FaqSection
              : null,
        ),
      );
    }
    return null;
  }

  List<Route<dynamic>> _initialRoutes(String _) => [
    _route(const RouteSettings(name: '/'))!,
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
          : ChangeNotifierProvider<AgeConfirmationSession>.value(
              value: _ageConfirmation,
              child: CityContactsLauncherScope(
                launch: widget.contactLauncher,
                child: _AdmittedApp(
                  child: ListenableBuilder(
                    listenable: _ageConfirmation,
                    child: child,
                    builder: (context, navigator) => CartPersistenceNotice(
                      navigatorKey: AppNavigator.key,
                      enabled: _ageConfirmation.isConfirmed,
                      child: navigator!,
                    ),
                  ),
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
