import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/certificates/ui/certificates_page.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object data) => http.Response(jsonEncode(data), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});
http.Response _list(List<Map<String, dynamic>> entries) => _json({
      'success': true,
      'data': {'certificates': entries}
    });
Widget _host() => ChangeNotifierProvider(
    create: (_) => CartProvider(),
    child:
        MaterialApp(theme: AppTheme.light(), home: const CertificatesPage()));

void main() {
  setUp(() =>
      SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'}));

  testWidgets('refused activation retains code and never reports success',
      (tester) async {
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/certificates') {
        return _list([]);
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/certificates/claim' &&
          jsonDecode(request.body)['code'] == 'NOT-FOUND') {
        return _json({'success': false, 'error': 'Сертификат не найден'});
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'NOT-FOUND');
      await tester.pump();
      await tester.tap(find.text('Ок'));
      await tester.pumpAndSettle();
      expect(find.text('Сертификат не найден'), findsOneWidget);
      expect(find.text('Сертификат активирован'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'NOT-FOUND');
    }, () => client);
  });

  testWidgets(
      'older active response cannot replace selected redeemed certificates',
      (tester) async {
    final active = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.method != 'GET' || request.url.path != '/api/certificates') {
        throw StateError('Unexpected request: ${request.url}');
      }
      if (request.url.queryParameters['status'] == 'active') {
        return active.future;
      }
      if (request.url.queryParameters['status'] == 'redeemed') {
        return _list([
          {'code': 'REDEEMED', 'balance': '0', 'initial_amount': 10000}
        ]);
      }
      throw StateError('Unexpected filter');
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pump();
      await tester.tap(find.text('Использованные'));
      await tester.pumpAndSettle();
      expect(find.text('REDEEMED'), findsOneWidget);
      expect(find.text('0 ₸'), findsOneWidget);
      active.complete(_list([
        {'code': 'ACTIVE', 'balance': 10000}
      ]));
      await tester.pumpAndSettle();
      expect(find.text('REDEEMED'), findsOneWidget);
      expect(find.text('ACTIVE'), findsNothing);
    }, () => client);
  });

  testWidgets('certificates beyond the first page remain reachable',
      (tester) async {
    final client = MockClient((request) async {
      if (request.method != 'GET' || request.url.path != '/api/certificates') {
        throw StateError('Unexpected request: ${request.url}');
      }
      if (request.url.queryParameters['offset'] == '0') {
        return _list([
          for (var id = 0; id < 50; id++) {'code': 'CERT-$id', 'balance': 10000}
        ]);
      }
      if (request.url.queryParameters['offset'] == '50') {
        return _list([
          {'code': 'FINAL-51', 'balance': 2000}
        ]);
      }
      throw StateError('Unexpected offset');
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      final more = find.text('Показать ещё');
      await tester.scrollUntilVisible(more, 400,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('FINAL-51'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('FINAL-51'), findsOneWidget);
      expect(find.text('Показать ещё'), findsNothing);
    }, () => client);
  });
}
