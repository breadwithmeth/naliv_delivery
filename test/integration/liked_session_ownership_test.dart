import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/core/like_action.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/favorites/ui/favorites_page.dart';
import 'package:naliv_delivery/pages/product_detail_page.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:naliv_delivery/utils/liked_storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../support/configuration_items.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'account-a',
      'liked_items_1': '[502]',
    });
    await AuthService.notifySessionChanged();
    await AuthService.bindAuthenticatedIdentity('user-a');
  });

  test('account switch clears business-only provider membership', () async {
    final likes = LikedItemsProvider()..updateLike(1, 502, true);
    addTearDown(likes.dispose);
    final transport = _SessionLikesTransport();
    await http.runWithClient(() async {
      await AuthService.saveToken('account-b');
      await AuthService.bindAuthenticatedIdentity('user-b');
      await likes.loadLiked(1);
      expect(likes.isLiked(1, 502), isFalse);
    }, () => transport.client);
  });

  test('guest cannot retain the previous account provider membership',
      () async {
    final likes = LikedItemsProvider()..updateLike(1, 502, true);
    addTearDown(likes.dispose);
    await (await SharedPreferences.getInstance()).remove('auth_token');
    await AuthService.notifySessionChanged();
    expect(likes.isLiked(1, 502), isFalse);
  });

  test('persisted liked membership belongs to its verified account', () async {
    await LikedStorageService.setLiked(businessId: 1, itemId: 503, liked: true);
    await AuthService.saveToken('account-b');
    await AuthService.bindAuthenticatedIdentity('user-b');
    expect(await LikedStorageService.getLikedIds(businessId: 1), isEmpty);
    await LikedStorageService.setLiked(businessId: 1, itemId: 504, liked: true);
    await AuthService.saveToken('account-a');
    await AuthService.bindAuthenticatedIdentity('user-a');
    expect(await LikedStorageService.getLikedIds(businessId: 1), {503});
    expect((await SharedPreferences.getInstance()).getString('liked_items_1'),
        '[502]',
        reason: 'Legacy ownerless data is ignored, not destroyed');
  });

  test('delayed prior-account likes refresh cannot publish into new account',
      () async {
    final transport = _SessionLikesTransport();
    final likes = LikedItemsProvider();
    addTearDown(likes.dispose);
    await http.runWithClient(() async {
      final pending = likes.loadLiked(1);
      await transport.started.future;
      await AuthService.saveToken('account-b');
      await AuthService.bindAuthenticatedIdentity('user-b');
      transport.completePage();
      await pending;
      expect(likes.isLiked(1, 502), isFalse);
      expect(await LikedStorageService.getLikedIds(businessId: 1), isEmpty);
    }, () => transport.client);
  });

  testWidgets(
      'delayed prior-account toggle cannot publish or persist into new account',
      (tester) async {
    final transport = _SessionLikesTransport();
    final likes = LikedItemsProvider();
    bool? result;
    await http.runWithClient(() async {
      await _mount(
          tester,
          likes,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result =
                      await toggleItemLike(context, businessId: 1, itemId: 502);
                },
                child: const Text('Изменить'),
              ),
            ),
          ));
      await tester.tap(find.text('Изменить'));
      await tester.pump();
      await transport.started.future;
      await AuthService.saveToken('account-b');
      await AuthService.bindAuthenticatedIdentity('user-b');
      transport.completeToggle();
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(likes.isLiked(1, 502), isFalse);
      expect(await LikedStorageService.getLikedIds(businessId: 1), isEmpty);
    }, () => transport.client);
  });

  testWidgets(
      'confirmed toggle survives rejected local cache write with visible warning',
      (tester) async {
    final previous = SharedPreferencesStorePlatform.instance;
    SharedPreferences.resetStatic();
    final store = _RefusingLikesStore({'flutter.auth_token': 'account-a'});
    SharedPreferencesStorePlatform.instance = store;
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = previous;
      SharedPreferences.resetStatic();
      expect(store.unexpected, isEmpty);
    });
    final transport = _SessionLikesTransport();
    final likes = LikedItemsProvider();
    bool? result;
    await http.runWithClient(() async {
      await _mount(
          tester,
          likes,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result =
                      await toggleItemLike(context, businessId: 1, itemId: 502);
                },
                child: const Text('Изменить'),
              ),
            ),
          ),
          withCart: false);
      await tester.tap(find.text('Изменить'));
      await tester.pump();
      await transport.started.future;
      transport.completeToggle();
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(likes.isLiked(1, 502), isTrue);
      expect(await LikedStorageService.getLikedIds(businessId: 1), isEmpty);
      expect(find.text('Избранное изменено, но не сохранено на устройстве'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => transport.client);
  });

  testWidgets('delayed options-detail toggle cannot publish into next account',
      (tester) async {
    final transport = _SessionLikesTransport();
    final likes = LikedItemsProvider();
    await http.runWithClient(() async {
      await _mount(tester, likes,
          ProductDetailPage(item: fixtureOptionItem(), businessId: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('configuration-like')));
      await tester.pump();
      await transport.started.future;
      await AuthService.saveToken('account-b');
      await AuthService.bindAuthenticatedIdentity('user-b');
      transport.completeToggle();
      await tester.pumpAndSettle();
      expect(likes.isLiked(1, 502), isFalse);
      expect(await LikedStorageService.getLikedIds(businessId: 1), isEmpty);
      expect(find.byTooltip('В избранное'), findsOneWidget);
      expect(find.byTooltip('Убрать из избранного'), findsNothing);
    }, () => transport.client);
  });

  testWidgets(
      'pending prior-account favorites page cannot display private rows',
      (tester) async {
    final transport = _SessionLikesTransport();
    final likes = LikedItemsProvider();
    await http.runWithClient(() async {
      await _mount(tester, likes, const FavoritesPage(businessId: 1));
      await transport.started.future;
      await AuthService.saveToken('account-b');
      await AuthService.bindAuthenticatedIdentity('user-b');
      transport.completePage();
      await tester.pumpAndSettle();
      expect(find.text('Лимонад'), findsNothing);
    }, () => transport.client);
  });

  for (final guest in [false, true]) {
    testWidgets(
        'ownerless legacy likes do not color ${guest ? 'guest' : 'new account'} detail heart',
        (tester) async {
      if (guest) {
        await (await SharedPreferences.getInstance()).remove('auth_token');
        await AuthService.notifySessionChanged();
      } else {
        await AuthService.saveToken('account-b');
        await AuthService.bindAuthenticatedIdentity('user-b');
      }
      await _mount(tester, LikedItemsProvider(),
          ProductDetailPage(item: fixtureOptionItem(), businessId: 1));
      await tester.pumpAndSettle();
      expect(find.byTooltip('В избранное'), findsOneWidget);
      expect(find.byTooltip('Убрать из избранного'), findsNothing);
      expect((await SharedPreferences.getInstance()).getString('liked_items_1'),
          '[502]');
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _mount(WidgetTester tester, LikedItemsProvider likes, Widget home,
    {bool withCart = true}) async {
  final cart = withCart ? CartProvider() : null;
  if (cart != null) {
    await cart.bindBusiness(1);
    addTearDown(cart.dispose);
  }
  addTearDown(likes.dispose);
  await tester.pumpWidget(MultiProvider(
    providers: [
      if (cart != null) ChangeNotifierProvider.value(value: cart),
      ChangeNotifierProvider.value(value: likes),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: home),
  ));
  await tester.pump();
}

class _SessionLikesTransport {
  _SessionLikesTransport() {
    client = MockClient((request) async {
      final url = request.url;
      final query = url.queryParameters;
      final authorization = request.headers['authorization'];
      final validRead = request.method == 'GET' &&
          url.path == '/api/users/liked-items' &&
          query.length == 3 &&
          query['business_id'] == '1' &&
          query['page'] == '1' &&
          const {'20', '500'}.contains(query['limit']);
      final validToggle = request.method == 'POST' &&
          url.path == '/api/users/liked-items/toggle' &&
          query.isEmpty &&
          request.body == '{"item_id":502}';
      if (url.scheme != 'https' ||
          url.host != 'njt25.naliv.kz' ||
          (!validRead && !validToggle)) {
        return _reject(request);
      }
      if (authorization == 'Bearer account-b' && validRead) {
        return _page([]);
      }
      if (authorization != 'Bearer account-a' || started.isCompleted) {
        return _reject(request);
      }
      started.complete();
      return _response.future;
    });
    addTearDown(() {
      expect(unexpected, isEmpty);
      client.close();
    });
  }

  late final MockClient client;
  final started = Completer<void>();
  final _response = Completer<http.Response>();
  final unexpected = <String>[];

  void completePage() =>
      _response.complete(_page([fixtureOptionItem().toJson()]));

  void completeToggle() => _response.complete(http.Response(
        jsonEncode({
          'success': true,
          'data': {'is_liked': true}
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ));

  http.Response _page(List<Map<String, dynamic>> items) => http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'items': items,
            'pagination': {'page': 1, 'total_pages': 1},
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  http.Response _reject(http.Request request) {
    unexpected
        .add('$request authorization=${request.headers['authorization']}');
    throw StateError('Unexpected request: $request');
  }
}

class _RefusingLikesStore extends InMemorySharedPreferencesStore {
  _RefusingLikesStore(super.values) : super.withData();
  final unexpected = <String>[];

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.startsWith('flutter.liked_items_')) return false;
    unexpected.add(key);
    throw StateError('Unexpected preference write: $key');
  }
}
