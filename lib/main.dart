import 'dart:async';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/utils/location_service.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:naliv_delivery/utils/app_navigator.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Инициализация сервиса уведомлений
  await NotificationService.instance.initialize();

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
        navigatorKey: AppNavigator.key,
        navigatorObservers: [routeObserver],
        title: "Налив/Градусы24",
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
        home: const AuthenticationWrapper());
  }
}
