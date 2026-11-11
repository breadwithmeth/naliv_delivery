import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/tokens.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/services/app_update_service.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/widgets/app_update_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/preferences_store.dart';
import '../support/design_surfaces.dart';

const _notice = ValueKey('app-update-notice');
const _later = ValueKey('app-update-later');
const _update = ValueKey('app-update-now');
const _error = ValueKey('app-update-open-error');
const _snooze = 'app_update_snooze_android_1.2.118';

void main() {
  late OnboardingPreferences prefs;
  late MockClient client;
  late List<String> unexpected;
  late DateTime now;
  late int requests;
  Future<http.Response> Function()? respond;

  AppUpdateService service({
    AppUpdatePlatform? platform = AppUpdatePlatform.android,
    Future<bool> Function(Uri)? open,
  }) => AppUpdateService(
    platform: platform,
    installedVersion: () async => '1.2.117',
    now: () => now,
    openUrl: open ?? (_) async => true,
  );

  Future<void> mount(
    WidgetTester tester,
    AppUpdateService updateService, {
    Brightness theme = Brightness.light,
    Key? key,
    GlobalKey<NavigatorState>? navigator,
    double scale = 1,
    double keyboard = 0,
  }) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      theme: theme == Brightness.light ? AppTheme.light() : AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: child!,
      ),
      home: AppUpdateNotice(
        key: key,
        service: updateService,
        child: Scaffold(
          body: Column(
            children: [
              const TextField(),
              Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(
                        body: Text('Оплата — без финансовых запросов'),
                      ),
                    ),
                  ),
                  child: const Text('Открыть оплату'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  setUp(() {
    prefs = OnboardingPreferences()..install();
    now = DateTime.utc(2026, 11, 11, 12);
    requests = 0;
    respond = null;
    unexpected = [];
    client = MockClient((r) async {
      if (r.method != 'GET' ||
          r.url.toString() != 'https://app.gradusy24.kz/app-update.json' ||
          r.headers.containsKey('Authorization')) {
        unexpected.add('${r.method} ${r.url}');
        throw StateError('Unexpected notice request');
      }
      requests++;
      return respond != null
          ? respond!()
          : http.Response('{"android":"1.2.118","ios":"1.2.118"}', 200);
    });
  });
  tearDown(() {
    client.close();
    expect(unexpected, isEmpty);
    SharedPreferences.setMockInitialValues({});
  });

  for (final theme in Brightness.values) {
    for (final dismissal in ['later', 'back', 'barrier']) {
      testWidgets(
        '$theme $dismissal preserves input/cart and durable reminder boundary',
        (tester) async {
          await http.runWithClient(() async {
            final cart = CartProvider();
            addTearDown(cart.dispose);
            await cart.ensureLoaded();
            cart.addItem(
              CartItem(
                itemId: 8101,
                name: 'Тоник',
                price: 100,
                quantity: 1,
                stepQuantity: 1,
                selectedVariants: const [],
                promotions: const [],
              ),
            );
            await cart.ensureSaved();
            final held = Completer<http.Response>();
            respond = () => held.future;
            await mount(tester, service(), theme: theme);
            await tester.enterText(find.byType(TextField), 'Мой поиск');
            held.complete(http.Response('{"android":"1.2.118"}', 200));
            await tester.pumpAndSettle();
            expect(find.byKey(_notice), findsOneWidget);
            if (dismissal == 'later') {
              await tester.tap(find.byKey(_later));
            } else if (dismissal == 'back') {
              await tester.binding.handlePopRoute();
            } else {
              await tester.tapAt(const Offset(5, 5));
            }
            await tester.pumpAndSettle();
            expect(find.byKey(_notice), findsNothing);
            expect(find.text('Мой поиск'), findsOneWidget);
            await tester.enterText(
              find.byType(TextField),
              'Поиск продолжается',
            );
            expect(find.text('Поиск продолжается'), findsOneWidget);
            expect(cart.getTotalQuantityForItem(8101), 1);
            await tester.pumpWidget(const SizedBox.shrink());
            prefs.install();
            respond = null;
            now = now.add(const Duration(hours: 23, minutes: 59, seconds: 59));
            await mount(tester, service(), theme: theme);
            await tester.pumpAndSettle();
            expect(find.byKey(_notice), findsNothing);
            await tester.pumpWidget(const SizedBox.shrink());
            now = now.add(const Duration(seconds: 1));
            await mount(tester, service(), theme: theme);
            await tester.pumpAndSettle();
            expect(find.byKey(_notice), findsOneWidget);
            await tester.tap(find.byKey(_later));
            await tester.pumpAndSettle();
            await tester.pumpWidget(const SizedBox.shrink());
            expect(tester.takeException(), isNull);
          }, () => client);
        },
      );
    }
  }

  for (final failure in ['false', 'throw']) {
    testWidgets(
      'launch $failure leaves retry and Later available; explicit retry snoozes',
      (tester) async {
        await http.runWithClient(() async {
          var attempts = 0;
          await mount(
            tester,
            service(
              open: (uri) async {
                expect(
                  uri.toString(),
                  'https://play.google.com/store/apps/details?id=kz.gradusy24.app',
                );
                if (++attempts == 1) {
                  if (failure == 'throw') throw StateError('launcher');
                  return false;
                }
                return true;
              },
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(_update));
          await tester.pumpAndSettle();
          expect(find.byKey(_error), findsOneWidget);
          expect(find.byKey(_later).hitTestable(), findsOneWidget);
          await tester.tap(find.byKey(_update));
          await tester.pumpAndSettle();
          expect(find.byKey(_notice), findsNothing);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          expect(find.byKey(_notice), findsNothing);
          expect(
            (await SharedPreferences.getInstance()).get(_snooze),
            now.add(const Duration(hours: 24)).millisecondsSinceEpoch,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      },
    );
  }

  testWidgets(
    'Later dismisses held launch/write; late success cannot pop payment',
    (tester) async {
      await http.runWithClient(() async {
        final launch = Completer<bool>();
        final write = Completer<bool>();
        prefs
          ..heldKey = _snooze
          ..heldWrite = write;
        await mount(tester, service(open: (_) => launch.future));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_update));
        await tester.pump();
        expect(
          tester.widget<FilledButton>(find.byKey(_update)).onPressed,
          isNull,
        );
        await tester.tap(find.byKey(_later));
        await tester.pumpAndSettle();
        expect(find.byKey(_notice), findsNothing);
        await tester.tap(find.text('Открыть оплату'));
        await tester.pumpAndSettle();
        launch.complete(true);
        await tester.pumpAndSettle();
        expect(find.text('Оплата — без финансовых запросов'), findsOneWidget);
        write.complete(false);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );

  testWidgets(
    'resume during a held check preserves the newest foreground opportunity',
    (tester) async {
      await http.runWithClient(() async {
        final held = Completer<http.Response>();
        respond = () => held.future;
        await mount(tester, service());
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        expect(requests, 1);
        held.complete(http.Response('{"android":"1.2.118"}', 200));
        await tester.pumpAndSettle();
        expect(find.byKey(_notice), findsOneWidget);
        await tester.tap(find.byKey(_later));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );

  testWidgets(
    'held foreground check never overlays payment or background; next resume may offer',
    (tester) async {
      await http.runWithClient(() async {
        final held = Completer<http.Response>();
        respond = () => held.future;
        final navigator = GlobalKey<NavigatorState>();
        await mount(tester, service(), navigator: navigator);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(requests, 1);
        await tester.tap(find.text('Открыть оплату'));
        await tester.pumpAndSettle();
        held.complete(http.Response('{"android":"1.2.118"}', 200));
        await tester.pumpAndSettle();
        expect(find.byKey(_notice), findsNothing);
        expect(find.text('Оплата — без финансовых запросов'), findsOneWidget);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.byKey(_notice), findsNothing);
        respond = null;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(_notice), findsOneWidget);
        await tester.tap(find.byKey(_later));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );

  testWidgets('background and disposed checks cannot present stale offers', (
    tester,
  ) async {
    await http.runWithClient(() async {
      final held = Completer<http.Response>();
      respond = () => held.future;
      await mount(tester, service());
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      held.complete(http.Response('{"android":"1.2.118"}', 200));
      await tester.pumpAndSettle();
      expect(find.byKey(_notice), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final disposed = Completer<http.Response>();
      respond = () => disposed.future;
      await mount(tester, service());
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      disposed.complete(http.Response('{"android":"1.2.118"}', 200));
      await tester.pumpAndSettle();
      expect(find.byKey(_notice), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets(
    'unsupported default remains interactive without metadata traffic',
    (tester) async {
      await http.runWithClient(() async {
        await mount(tester, AppUpdateService.production());
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Работает офлайн');
        expect(find.text('Работает офлайн'), findsOneWidget);
        expect(requests, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final theme in Brightness.values) {
    testWidgets(
      '$theme narrow large text keyboard keeps both actions reachable',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await http.runWithClient(() async {
          await mount(
            tester,
            service(open: (_) async => false),
            theme: theme,
            scale: 2,
            keyboard: 300,
          );
          await tester.pumpAndSettle();
          for (final key in [_update, _later]) {
            await tester.ensureVisible(find.byKey(key));
            expect(find.byKey(key).hitTestable(), findsOneWidget);
            final size = tester.getSize(find.byKey(key));
            expect(size.height, greaterThanOrEqualTo(AppSpacing.touchTarget));
            expect(size.width, greaterThanOrEqualTo(AppSpacing.touchTarget));
          }
          await tester.tap(find.byKey(_update));
          await tester.pumpAndSettle();
          expect(find.byKey(_error), findsOneWidget);
          await tester.ensureVisible(find.byKey(_later));
          await tester.tap(find.byKey(_later));
          await tester.pumpAndSettle();
          expect(find.byKey(_notice), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );
  }

  for (final scenario in [
    AppUpdateFixtureScenario.android,
    AppUpdateFixtureScenario.ios,
    AppUpdateFixtureScenario.androidOpenFailed,
    AppUpdateFixtureScenario.iosOpenFailed,
  ]) {
    testWidgets(
      'active fixture $scenario uses real notice and synthetic store only',
      (tester) async {
        SharedPreferences.setMockInitialValues(surfaceFixturePreferences);
        SurfaceFixtureClient.resetUnexpectedRequests();
        final nativeCalls = <String>[];
        const channels = [
          MethodChannel('dev.fluttercommunity.plus/package_info'),
          MethodChannel('plugins.flutter.io/url_launcher'),
        ];
        for (final channel in channels) {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (call) async {
              nativeCalls.add(call.method);
              throw StateError('Native plugin in fixture');
            },
          );
        }
        final fixture = SurfaceFixtureClient();
        addTearDown(() {
          fixture.close();
          for (final channel in channels) {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              channel,
              null,
            );
          }
          expect(nativeCalls, isEmpty);
          expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
        });
        await http.runWithClient(() async {
          await tester.pumpWidget(
            DesignSurfaceApp(
              surface: 'active_route',
              brightness: Brightness.dark,
              updateScenario: scenario,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(_notice), findsOneWidget);
          await tester.tap(find.byKey(_update));
          await tester.pumpAndSettle();
          final failed = scenario.name.endsWith('OpenFailed');
          if (failed) {
            expect(find.byKey(_error), findsOneWidget);
            await tester.tap(find.byKey(_later));
            await tester.pumpAndSettle();
          } else {
            expect(
              find.text(
                scenario == AppUpdateFixtureScenario.android
                    ? 'Фикстура Google Play · kz.gradusy24.app'
                    : 'Фикстура App Store · 6473792920',
              ),
              findsOneWidget,
            );
          }
          expect(find.byKey(_notice), findsNothing);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          expect(find.byKey(_notice), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
          expect(tester.takeException(), isNull);
        }, () => fixture);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'fixture off and non-active surfaces never fetch mobile metadata; switching drops stale work',
    (tester) async {
      SharedPreferences.setMockInitialValues(surfaceFixturePreferences);
      SurfaceFixtureClient.resetUnexpectedRequests();
      final fixture = SurfaceFixtureClient();
      final held = Completer<http.Response>();
      var updates = 0;
      final transport = MockClient((request) async {
        if (request.url.toString() ==
            'https://app.gradusy24.kz/app-update.json') {
          updates++;
          return held.future;
        }
        final forwarded = http.Request(request.method, request.url)
          ..headers.addAll(request.headers)
          ..bodyBytes = request.bodyBytes;
        return http.Response.fromStream(await fixture.send(forwarded));
      });
      addTearDown(() {
        fixture.close();
        transport.close();
        expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const DesignSurfaceApp(
            surface: 'active_route',
            brightness: Brightness.dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(updates, 0);
        expect(find.text('Не удалось загрузить'), findsNothing);
        expect(find.text('Тестовый магазин'), findsWidgets);
        await tester.pumpWidget(
          const DesignSurfaceApp(
            surface: 'home',
            brightness: Brightness.dark,
            updateScenario: AppUpdateFixtureScenario.android,
          ),
        );
        await tester.pumpAndSettle();
        expect(updates, 0);
        await tester.pumpWidget(
          const DesignSurfaceApp(
            surface: 'active_route',
            brightness: Brightness.dark,
            updateScenario: AppUpdateFixtureScenario.android,
          ),
        );
        await tester.pumpAndSettle();
        expect(updates, 1);
        await tester.pumpWidget(
          const DesignSurfaceApp(
            surface: 'active_route',
            brightness: Brightness.dark,
          ),
        );
        await tester.pumpAndSettle();
        held.complete(http.Response('{"android":"1.2.118"}', 200));
        await tester.pumpAndSettle();
        expect(find.byKey(_notice), findsNothing);
        expect(updates, 1);
        expect(find.text('Тестовый магазин'), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      }, () => transport);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
