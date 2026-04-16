import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gradusy24/utils/location_service.dart';
import 'package:gradusy24/utils/cart_provider.dart';
import 'package:gradusy24/utils/business_provider.dart';
import 'package:gradusy24/utils/browser_route_history_observer.dart';
import 'package:gradusy24/utils/liked_items_provider.dart';
import 'package:gradusy24/services/notification_service.dart';
import 'package:gradusy24/services/telemetry_consent_service.dart';
import 'package:gradusy24/utils/responsive.dart';
import 'package:gradusy24/widgets/app_entry_gate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'firebase_options.dart';
import 'package:gradusy24/utils/app_navigator.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
final BrowserRouteHistoryObserver browserRouteHistoryObserver = BrowserRouteHistoryObserver();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TelemetryConsentService.loadConsent();
  final packageInfo = await PackageInfo.fromPlatform();

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://d19c02e97e5b55f26c69d3cbd7ad8394@o4510957798883328.ingest.us.sentry.io/4511133765271552';
      options.environment = kReleaseMode ? 'production' : 'development';
      options.release = '${packageInfo.packageName}@${packageInfo.version}+${packageInfo.buildNumber}';
      options.tracesSampleRate = 1.0;
      options.enableAutoSessionTracking = true;
      options.sendDefaultPii = true;
      options.beforeSend = (event, hint) {
        if (!TelemetryConsentService.cachedConsent) {
          // Strip user-identifiable data when consent is off.
          event
            ..user = null
            ..request = null;
        }
        return event;
      };
    },
    appRunner: () async {
      // Инициализация Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Инициализация сервиса уведомлений
      await NotificationService.instance.initialize();

      FlutterError.onError = (details) {
        Sentry.captureException(details.exception, stackTrace: details.stack);
        FlutterError.presentError(details);
      };

      runZonedGuarded(
        () {
          runApp(
            MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => CartProvider()),
                ChangeNotifierProvider(create: (_) => BusinessProvider()),
                ChangeNotifierProvider(create: (_) => LikedItemsProvider()),
              ],
              child: const Main(),
            ),
          );
        },
        (error, stack) async {
          await Sentry.captureException(error, stackTrace: stack);
        },
      );
    },
  );
}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> with LocationMixin {
  // Данные загруженные из API

  @override
  void initState() {
    super.initState();
    // Инициализируем корзину после создания виджета
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartProvider>(context, listen: false).loadCart();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        builder: (context, child) {
          Responsive.init(context);
          return child!;
        },
        navigatorKey: AppNavigator.key,
        navigatorObservers: [browserRouteHistoryObserver, routeObserver, SentryNavigatorObserver()],
        title: "Градусы24",
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ru'),
          Locale('en'),
        ],
        theme: ThemeData(
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: Color(0xffF9F9F9),
          appBarTheme: AppBarTheme(
            backgroundColor: Color(0xffF9F9F9),
            foregroundColor: Colors.black,
          ),
          colorScheme: const ColorScheme.light(
            surface: Color(0xFFF5F5F5),
            onSurface: Colors.black,
            primaryContainer: Colors.white,
            primary: Colors.black,
            onPrimary: Colors.white,
            surfaceDim: Colors.white,
            secondary: Color(0xFFFF6900),
            // onSecondaryContainer: Color(0xFF363636),
            secondaryContainer: Color(0xFFff991c),
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.black),
          ),
        ),
        darkTheme: ThemeData(
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          useMaterial3: true,
          brightness: Brightness.dark,
          appBarTheme: AppBarTheme(
            backgroundColor: Color(0xFF0a0a0a),
            surfaceTintColor: Color(0xFF0a0a0a),
            foregroundColor: Colors.white,
          ),
          scaffoldBackgroundColor: Color(0xFF0a0a0a),
          colorScheme: const ColorScheme.dark(
              surfaceDim: Colors.white10,
              surface: Color(0xFF0a0a0a),
              onSurface: Colors.white,
              primaryContainer: Color(0xFF363636),
              primary: Colors.white,
              secondaryContainer: Color(0xFFff991c),
              secondary: Color(0xFFFF6900),
              onPrimary: Colors.black),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white),
          ),
        ),
        debugShowCheckedModeBanner: false,
        home: const AppEntryGate());
  }
}
