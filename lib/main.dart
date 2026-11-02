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
          child: const Main(),
        ),
      );
    },
    (error, stack) async {
      await Sentry.captureException(error, stackTrace: stack);
    },
  );
}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  @override
  void initState() {
    super.initState();
    browserHistoryEnableExitWarning();
    // Инициализируем корзину после создания виджета
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<CartProvider>(context, listen: false).loadCart();
      unawaited(NotificationService.instance.initialize().catchError(
            (Object error) =>
                debugPrint('Push initialization unavailable: $error'),
          ));
    });
  }

  @override
  void dispose() {
    browserHistoryDisableExitWarning();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        navigatorKey: AppNavigator.key,
        builder: (context, child) => CartPersistenceNotice(
              navigatorKey: AppNavigator.key,
              child: child ?? const SizedBox.shrink(),
            ),
        navigatorObservers: [
          browserRouteHistoryObserver,
          routeObserver,
          SentryNavigatorObserver()
        ],
        title: "Градусы24",
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ru'),
          Locale('en'),
        ],
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // OS default with the user's override from the sidebar / profile switch.
        themeMode: context.watch<ThemeController>().mode,
        debugShowCheckedModeBanner: false,
        routes: {
          FaqPage.routeName: (context) {
            final arguments = ModalRoute.of(context)?.settings.arguments;
            return FaqPage(
              initialSection: arguments is FaqSection ? arguments : null,
            );
          },
        },
        home: const AppEntryGate());
  }
}
