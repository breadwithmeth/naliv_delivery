import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/search/ui/search_page.dart';
import 'package:naliv_delivery/ui/product_row.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('late search success cannot replace a newer submitted query',
      (tester) async {
    final transport = _SearchTransport();
    await http.runWithClient(() async {
      await _mount(tester);
      await _submit(tester, 'старое');
      await _submit(tester, 'новое');
      transport.complete('новое', 1, [_item(2, 'Новый результат')]);
      await tester.pumpAndSettle();
      expect(find.text('Новый результат'), findsOneWidget);
      transport.complete('старое', 1, [_item(1, 'Старый результат')]);
      await tester.pumpAndSettle();
      expect(find.text('Новый результат'), findsOneWidget);
      expect(find.text('Старый результат'), findsNothing);
    }, () => transport.client);
  });

  testWidgets('late search error cannot hide a newer successful query',
      (tester) async {
    final transport = _SearchTransport();
    await http.runWithClient(() async {
      await _mount(tester);
      await _submit(tester, 'старое');
      await _submit(tester, 'новое');
      transport.complete('новое', 1, [_item(2, 'Новый результат')]);
      await tester.pumpAndSettle();
      transport.fail('старое', 1);
      await tester.pumpAndSettle();
      expect(find.text('Новый результат'), findsOneWidget);
      expect(find.text('Не удалось выполнить поиск'), findsNothing);
    }, () => transport.client);
  });

  testWidgets('clearing pending search immediately returns to idle',
      (tester) async {
    final transport = _SearchTransport();
    await http.runWithClient(() async {
      await _mount(tester);
      await _submit(tester, 'старое');
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      transport.complete('старое', 1, [_item(1, 'Старый результат')]);
      await tester.pumpAndSettle();
      expect(find.byType(ProductRow), findsNothing);
      expect(find.text('Не удалось выполнить поиск'), findsNothing);
    }, () => transport.client);
  });

  testWidgets(
      'editing text invalidates pending response without auto searching',
      (tester) async {
    final transport = _SearchTransport();
    await http.runWithClient(() async {
      await _mount(tester);
      await _submit(tester, 'старое');
      await tester.enterText(find.byType(TextField), 'ещё не отправлено');
      await tester.pump();
      transport.complete('старое', 1, [_item(1, 'Старый результат')]);
      await tester.pumpAndSettle();
      expect(find.text('Старый результат'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(transport.requests, ['старое:1']);
    }, () => transport.client);
  });

  testWidgets(
      'search continuation appends all matches and retries same API page',
      (tester) async {
    final transport = _SearchTransport();
    await http.runWithClient(() async {
      await _mount(tester);
      await _submit(tester, 'товар');
      transport.complete(
        'товар',
        1,
        [
          for (var id = 1; id <= 40; id++)
            _item(id, id == 1 ? 'Начало списка' : 'Результат $id'),
        ],
        totalPages: 2,
      );
      await tester.pumpAndSettle();
      expect(find.text('Начало списка'), findsOneWidget);
      await _scrollToBottom(tester);
      expect(transport.requests, ['товар:1', 'товар:2']);
      transport.fail('товар', 2);
      await tester.pumpAndSettle();
      expect(find.text('Повторить загрузку'), findsOneWidget);
      await tester.tap(find.text('Повторить загрузку'));
      await tester.pump();
      expect(transport.requests, ['товар:1', 'товар:2', 'товар:2']);
      transport.complete('товар', 2, [_item(41, 'Последний результат')],
          totalPages: 2);
      await tester.pumpAndSettle();
      await _scrollToBottom(tester);
      expect(find.text('Последний результат'), findsOneWidget);
      final scrollable = tester.state<ScrollableState>(find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ));
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Начало списка'), findsOneWidget);
      expect(find.text('Показать ещё'), findsNothing);
    }, () => transport.client);
  });

  testWidgets(
      'search continuation uses returned API page rather than assumed offset',
      (tester) async {
    final transport = _SearchTransport();
    await http.runWithClient(() async {
      await _mount(tester);
      await _submit(tester, 'товар');
      transport.complete('товар', 1, [_item(1, 'Первый результат')],
          returnedPage: 3, totalPages: 4);
      await tester.pump();
      await tester.pump();
      expect(transport.requests, ['товар:1', 'товар:4']);
      transport.complete('товар', 4, [_item(2, 'Последний результат')],
          totalPages: 4);
      await tester.pumpAndSettle();
      expect(find.text('Первый результат'), findsOneWidget);
      expect(find.text('Последний результат'), findsOneWidget);
    }, () => transport.client);
  });

  testWidgets('search append is serialized and belongs to its submitted query',
      (tester) async {
    final transport = _SearchTransport();
    await http.runWithClient(() async {
      await _mount(tester);
      await _submit(tester, 'старое');
      transport.complete('старое', 1, [_item(1, 'Старый результат')],
          totalPages: 2);
      await tester.pump();
      await tester.pump();
      expect(transport.requests, ['старое:1', 'старое:2']);
      await tester.pump(const Duration(milliseconds: 100));
      expect(transport.requests, ['старое:1', 'старое:2']);
      await _submit(tester, 'новое');
      transport.complete('новое', 1, [_item(2, 'Новый результат')]);
      await tester.pumpAndSettle();
      transport.complete('старое', 2, [_item(3, 'Чужая следующая страница')],
          totalPages: 2);
      await tester.pumpAndSettle();
      expect(find.text('Новый результат'), findsOneWidget);
      expect(find.text('Чужая следующая страница'), findsNothing);
      expect(find.text('Старый результат'), findsNothing);
    }, () => transport.client);
  });
}

Future<void> _mount(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final cart = CartProvider();
  final likes = LikedItemsProvider();
  addTearDown(cart.dispose);
  addTearDown(likes.dispose);
  await cart.bindBusiness(1);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: cart),
      ChangeNotifierProvider.value(value: likes),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const SearchPage(businessId: 1),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
          of: find.byType(ListView), matching: find.byType(Scrollable)),
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
  }
}

Map<String, Object> _item(int id, String name) => {
      'item_id': id,
      'name': name,
      'price': 500,
      'amount': 20,
      'unit': 'шт.',
      'quantity_step': 1,
      'visible': 1,
    };

class _SearchTransport {
  _SearchTransport() {
    client = MockClient((request) async {
      final query = request.url.queryParameters;
      if (request.method != 'GET' ||
          request.url.scheme != 'https' ||
          request.url.host != 'njt25.naliv.kz' ||
          request.url.path != '/api/items/search' ||
          query.length != 4 ||
          query['business_id'] != '1' ||
          query['limit'] != '40' ||
          query['name']?.isNotEmpty != true ||
          int.tryParse(query['page'] ?? '') == null) {
        unexpected.add('$request');
        throw StateError('Unexpected request: $request');
      }
      final key = '${query['name']}:${query['page']}';
      requests.add(key);
      if (_pending.containsKey(key)) {
        unexpected.add('Concurrent duplicate: $key');
        throw StateError('Concurrent duplicate: $key');
      }
      final completer = Completer<http.Response>();
      _pending[key] = completer;
      return completer.future;
    });
    addTearDown(() {
      expect(unexpected, isEmpty);
      client.close();
    });
  }

  late final MockClient client;
  final unexpected = <String>[];
  final requests = <String>[];
  final _pending = <String, Completer<http.Response>>{};

  void complete(String query, int page, List<Map<String, Object>> items,
      {int totalPages = 1, int? returnedPage}) {
    _take(query, page).complete(http.Response(
      jsonEncode({
        'success': true,
        'data': {
          'items': items,
          'pagination': {
            'page': returnedPage ?? page,
            'limit': 40,
            'total': totalPages == 1 ? items.length : 41,
            'total_pages': totalPages,
            'has_next_page': (returnedPage ?? page) < totalPages,
          },
        },
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ));
  }

  void fail(String query, int page) =>
      _take(query, page).complete(http.Response('unavailable', 503));

  Completer<http.Response> _take(String query, int page) {
    final pending = _pending.remove('$query:$page');
    expect(pending, isNotNull, reason: 'Expected request $query page $page');
    return pending!;
  }
}
