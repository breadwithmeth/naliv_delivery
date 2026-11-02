import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/favorites/ui/favorites_page.dart';
import 'package:naliv_delivery/pages/product_detail_page.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/ui/product_row.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/configuration_items.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'fixture-token',
      'liked_items_1': '[502]',
    });
    await AuthService.notifySessionChanged();
    await AuthService.bindAuthenticatedIdentity('fixture-user');
  });

  testWidgets(
      'options detail unlike removes favorite without removing unknown rows',
      (tester) async {
    final transport = _LikesTransport();
    final likes = LikedItemsProvider()..updateLike(1, 502, true);
    await http.runWithClient(() async {
      await _mount(tester, likes);
      expect(_rowTitles(tester), ['Лимонад', 'Другой товар']);
      await tester.tap(find.text('Лимонад'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductDetailPage), findsOneWidget);
      await tester.tap(find.byTooltip('Убрать из избранного'));
      await tester.pumpAndSettle();
      expect(likes.isLiked(1, 502), isFalse);
      await tester.tap(find.byKey(const ValueKey('configuration-back')));
      await tester.pumpAndSettle();
      expect(_rowTitles(tester), ['Другой товар']);
      expect(transport.toggles, [502]);
    }, () => transport.client);
  });

  testWidgets(
      'unlike then re-like in options detail restores loaded membership',
      (tester) async {
    final transport = _LikesTransport();
    final likes = LikedItemsProvider()..updateLike(1, 502, true);
    await http.runWithClient(() async {
      await _mount(tester, likes);
      await tester.tap(find.text('Лимонад'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Убрать из избранного'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('В избранное'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('configuration-back')));
      await tester.pumpAndSettle();
      expect(_rowTitles(tester), ['Лимонад', 'Другой товар']);
      expect(transport.toggles, [502, 502]);
    }, () => transport.client);
  });

  testWidgets('row unlike can be reconciled with a later shared re-like',
      (tester) async {
    final transport = _LikesTransport();
    final likes = LikedItemsProvider()..updateLike(1, 502, true);
    await http.runWithClient(() async {
      await _mount(tester, likes);
      await tester.tap(find.descendant(
        of: find.byType(ProductRow).first,
        matching: find.byTooltip('Убрать из избранного'),
      ));
      await tester.pumpAndSettle();
      expect(_rowTitles(tester), ['Другой товар']);
      likes.updateLike(1, 502, true);
      await tester.pumpAndSettle();
      expect(_rowTitles(tester), ['Лимонад', 'Другой товар']);
    }, () => transport.client);
  });

  testWidgets('failed optimistic unlike restores row with confirmed membership',
      (tester) async {
    final transport = _LikesTransport()..failToggle = true;
    final likes = LikedItemsProvider()..updateLike(1, 502, true);
    await http.runWithClient(() async {
      await _mount(tester, likes);
      await tester.tap(find.descendant(
        of: find.byType(ProductRow).first,
        matching: find.byTooltip('Убрать из избранного'),
      ));
      await tester.pumpAndSettle();
      expect(_rowTitles(tester), ['Лимонад', 'Другой товар']);
      expect(likes.isLiked(1, 502), isTrue);
    }, () => transport.client);
  });

  testWidgets(
      'shared membership is store scoped and does not discard unknown favorites',
      (tester) async {
    final transport = _LikesTransport();
    final likes = LikedItemsProvider();
    await http.runWithClient(() async {
      await _mount(tester, likes);
      likes.updateLike(2, 502, false);
      likes.updateLike(1, 999, false);
      await tester.pumpAndSettle();
      expect(_rowTitles(tester), ['Лимонад', 'Другой товар']);
      likes.updateLike(1, 502, false);
      await tester.pumpAndSettle();
      expect(_rowTitles(tester), ['Другой товар']);
    }, () => transport.client);
  });

  testWidgets('pending favorite page cannot resurrect a confirmed unlike',
      (tester) async {
    final transport = _LikesTransport(paginate: true);
    final likes = LikedItemsProvider()..updateLike(1, 502, true);
    await http.runWithClient(() async {
      await _mount(tester, likes, settle: false);
      expect(transport.pages, [1, 2]);
      likes.updateLike(1, 502, false);
      transport.completeMore();
      await tester.pumpAndSettle();
      expect(_rowTitles(tester), ['Другой товар', 'Следующая страница']);
    }, () => transport.client);
  });

  testWidgets('pending favorite page preserves re-like without duplicate rows',
      (tester) async {
    final transport = _LikesTransport(paginate: true);
    final likes = LikedItemsProvider()..updateLike(1, 502, true);
    await http.runWithClient(() async {
      await _mount(tester, likes, settle: false);
      expect(transport.pages, [1, 2]);
      likes.updateLike(1, 502, false);
      likes.updateLike(1, 502, true);
      transport.completeMore();
      await tester.pumpAndSettle();
      expect(_rowTitles(tester),
          ['Лимонад', 'Другой товар', 'Следующая страница']);
    }, () => transport.client);
  });

  test('late shared likes refresh cannot overwrite confirmed unlike', () async {
    final transport = _LikesTransport();
    final likes = LikedItemsProvider()..updateLike(1, 502, true);
    addTearDown(likes.dispose);
    await http.runWithClient(() async {
      final refresh = likes.loadLiked(1);
      await transport.refreshStarted.future;
      likes.updateLike(1, 502, false);
      transport.completeRefresh([fixtureOptionItem().toJson()]);
      await refresh;
      expect(likes.isLiked(1, 502), isFalse);
    }, () => transport.client);
  });

  test('late shared likes refresh cannot erase a confirmed re-like', () async {
    final transport = _LikesTransport();
    final likes = LikedItemsProvider();
    addTearDown(likes.dispose);
    await http.runWithClient(() async {
      final refresh = likes.loadLiked(1);
      await transport.refreshStarted.future;
      likes.updateLike(1, 502, false);
      likes.updateLike(1, 502, true);
      transport.completeRefresh([]);
      await refresh;
      expect(likes.isLiked(1, 502), isTrue);
    }, () => transport.client);
  });
}

List<String> _rowTitles(WidgetTester tester) => tester
    .widgetList<ProductRow>(find.byType(ProductRow))
    .map((row) => row.title)
    .toList();

Future<void> _mount(WidgetTester tester, LikedItemsProvider likes,
    {bool settle = true}) async {
  await tester.binding.setSurfaceSize(const Size(375, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final cart = CartProvider();
  await cart.bindBusiness(1);
  addTearDown(cart.dispose);
  addTearDown(likes.dispose);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: cart),
      ChangeNotifierProvider.value(value: likes),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const FavoritesPage(businessId: 1),
    ),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
}

Map<String, dynamic> _plainItem(int id, String name) => {
      'item_id': id,
      'name': name,
      'price': 500,
      'amount': 20,
      'unit': 'шт.',
    };

http.Response _page(List<Map<String, dynamic>> items,
        {int page = 1, int totalPages = 1}) =>
    http.Response(
      jsonEncode({
        'success': true,
        'data': {
          'items': items,
          'pagination': {'page': page, 'total_pages': totalPages},
        },
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

class _LikesTransport {
  _LikesTransport({this.paginate = false}) {
    client = MockClient((request) async {
      final url = request.url;
      final query = url.queryParameters;
      if (url.scheme != 'https' ||
          url.host != 'njt25.naliv.kz' ||
          request.headers['authorization'] != 'Bearer fixture-token') {
        return _reject(request);
      }
      if (request.method == 'GET' &&
          url.path == '/api/users/liked-items' &&
          query.length == 3 &&
          query['business_id'] == '1') {
        if (query['page'] == '1' && query['limit'] == '500') {
          refreshStarted.complete();
          return _refresh.future;
        }
        if (query['limit'] != '20') return _reject(request);
        if (query['page'] == '1') {
          pages.add(1);
          return _page([
            fixtureOptionItem().toJson(),
            _plainItem(503, 'Другой товар'),
          ], totalPages: paginate ? 2 : 1);
        }
        if (query['page'] == '2' && paginate) {
          pages.add(2);
          return _more.future;
        }
      }
      if (request.method == 'POST' &&
          url.path == '/api/users/liked-items/toggle' &&
          query.isEmpty &&
          request.body == '{"item_id":502}') {
        toggles.add(502);
        if (failToggle) return http.Response('unavailable', 503);
        _liked = !_liked;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'is_liked': _liked}
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return _reject(request);
    });
    addTearDown(() {
      expect(unexpected, isEmpty);
      client.close();
    });
  }

  final bool paginate;
  late final MockClient client;
  final unexpected = <String>[];
  final pages = <int>[];
  final toggles = <int>[];
  final refreshStarted = Completer<void>();
  final _refresh = Completer<http.Response>();
  final _more = Completer<http.Response>();
  bool _liked = true;
  bool failToggle = false;

  void completeMore() => _more.complete(_page([
        fixtureOptionItem().toJson(),
        _plainItem(504, 'Следующая страница'),
      ], page: 2, totalPages: 2));

  void completeRefresh(List<Map<String, dynamic>> items) =>
      _refresh.complete(_page(items));

  http.Response _reject(http.Request request) {
    unexpected.add('$request');
    throw StateError('Unexpected request: $request');
  }
}
