import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/home/home_screen.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/design_surfaces.dart';

http.Response _previousAccount() => http.Response(
      jsonEncode({
        'success': true,
        'data': {
          'user': {
            'id': 111,
            'name': 'Предыдущий пользователь',
            'login': '+7 (000) 000-00-01',
            'date_of_birth': '1990-08-05',
            'sex': 0,
          },
          'addresses': [],
          'cards': [],
          'certificates': [],
        },
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  testWidgets('late signed-in home load cannot restore an ended session',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    SharedPreferences.setMockInitialValues(surfaceFixturePreferences);
    SurfaceFixtureClient.resetUnexpectedRequests();
    final delayedHome = Completer<http.Response>();
    final fixture = SurfaceFixtureClient();
    final unexpected = <String>[];
    var promotionReads = 0;
    http.Response? oldPromotions;
    final client = MockClient((request) async {
      if (request.method != 'GET') {
        unexpected.add('${request.method} ${request.url}');
        throw StateError(unexpected.last);
      }
      final response = await fixture.get(request.url, headers: request.headers);
      if (request.url.path == '/api/promotions/active' &&
          ++promotionReads == 1) {
        oldPromotions = response;
        return delayedHome.future;
      }
      return response;
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      if (!delayedHome.isCompleted && oldPromotions != null) {
        delayedHome.complete(oldPromotions);
      }
      client.close();
      fixture.close();
      await tester.binding.setSurfaceSize(null);
      expect(unexpected, isEmpty);
      expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => BusinessProvider()),
          ChangeNotifierProvider(create: (_) => LikedItemsProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const AuthenticationWrapper(),
        ),
      ));
      for (var turn = 0; turn < 12; turn++) {
        await tester.pump();
      }
      expect(oldPromotions, isNotNull);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await AuthService.notifySessionChanged();
      await tester.pumpAndSettle();
      expect(tester.widget<HomeScreen>(find.byType(HomeScreen)).data.signedIn,
          isFalse);

      delayedHome.complete(oldPromotions);
      await tester.pumpAndSettle();
      final home = tester.widget<HomeScreen>(find.byType(HomeScreen)).data;
      expect(home.signedIn, isFalse);
      expect(home.bonusCardCode, isNull);
      expect(home.activeOrder, isNull);
    }, () => client);
  });

  for (final signedIn in [true, false]) {
    testWidgets(
        signedIn
            ? 'a new session bypasses an old pending account read and coalesces its own refreshes'
            : 'ending a session shows guest home without waiting for its old account read',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      SharedPreferences.setMockInitialValues(surfaceFixturePreferences);
      SurfaceFixtureClient.resetUnexpectedRequests();
      final previous = Completer<http.Response>();
      final replacement = Completer<http.Response>();
      final accountReads = <String?>[];
      final fixture = SurfaceFixtureClient();
      final client = MockClient((request) {
        if (request.method != 'GET') {
          throw StateError('Unexpected mutation: $request');
        }
        final authorization = request.headers['Authorization'];
        if (request.url.path == '/api/auth/full-info') {
          accountReads.add(authorization);
          if (authorization == 'Bearer fixture-only') return previous.future;
          if (authorization == 'Bearer replacement-fixture') {
            return replacement.future;
          }
          throw StateError('Unexpected account credentials: $authorization');
        }
        return fixture.get(request.url, headers: {
          ...request.headers,
          if (authorization != null) 'Authorization': 'Bearer fixture-only',
        });
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        if (!previous.isCompleted) previous.complete(_previousAccount());
        if (!replacement.isCompleted) replacement.complete(_previousAccount());
        await tester.pump();
        await AuthService.bindAuthenticatedIdentity(null);
        client.close();
        fixture.close();
        await tester.binding.setSurfaceSize(null);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CartProvider()),
            ChangeNotifierProvider(create: (_) => BusinessProvider()),
            ChangeNotifierProvider(create: (_) => LikedItemsProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const AuthenticationWrapper(),
          ),
        ));
        await tester.pump();
        expect(accountReads, ['Bearer fixture-only']);

        if (signedIn) {
          await AuthService.saveToken('replacement-fixture');
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token');
          await AuthService.notifySessionChanged();
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        if (signedIn) {
          expect(accountReads,
              ['Bearer fixture-only', 'Bearer replacement-fixture']);
        } else {
          expect(find.byType(HomeScreen), findsOneWidget);
          expect(
              tester.widget<HomeScreen>(find.byType(HomeScreen)).data.signedIn,
              isFalse);
        }

        previous.complete(_previousAccount());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        if (signedIn) {
          expect(find.byType(HomeScreen), findsNothing,
              reason: 'old account data must not publish before the new read');
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await tester.pump();
          expect(accountReads,
              ['Bearer fixture-only', 'Bearer replacement-fixture']);
          replacement.complete(await fixture.get(
            Uri.parse('https://njt25.naliv.kz/api/auth/full-info'),
            headers: {'Authorization': 'Bearer fixture-only'},
          ));
        }
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.widget<HomeScreen>(find.byType(HomeScreen)).data.signedIn,
            signedIn);
        expect(AuthService.currentIdentity, signedIn ? '999' : isNull);
        expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
        expect(tester.takeException(), isNull);
      }, () => client);
    });
  }
}
