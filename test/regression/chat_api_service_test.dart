import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/services/chat_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _messagesPath =
    '/api/widget/wgt_Ioj4vp2arln68wZeSMeyWd4l/sessions/fixture-session/messages';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({
        'chat_widget_session': jsonEncode({
          'id': 'fixture-session',
          'identity': null,
          'token': 'fixture-token',
        }),
      }));

  test('sending does not advance polling past an unseen support reply',
      () async {
    final unexpected = <String>[];
    final client = MockClient((request) async {
      if (request.url.host != 'bm.drawbridge.kz' ||
          request.url.path != _messagesPath ||
          request.headers['authorization'] != 'Bearer fixture-token') {
        unexpected.add('${request.method} ${request.url}');
        throw StateError(unexpected.last);
      }
      if (request.method == 'POST' &&
          request.url.queryParameters.isEmpty &&
          request.body == jsonEncode({'content': 'Следующий вопрос'})) {
        return _json({
          'message': {
            'id': 3,
            'content': 'Следующий вопрос',
            'fromMe': false,
          }
        }, 201);
      }
      if (request.method == 'GET' &&
          request.url.queryParameters['limit'] == '100') {
        if (request.url.queryParameters.length == 1) {
          return _json({
            'messages': [
              {'id': 1, 'content': 'Первый ответ', 'fromMe': true},
            ]
          });
        }
        if (request.url.queryParameters.length == 2 &&
            request.url.queryParameters['afterId'] == '1') {
          return _json({
            'messages': [
              {'id': 2, 'content': 'Ответ между отправками', 'fromMe': true},
              {'id': 3, 'content': 'Следующий вопрос', 'fromMe': false},
            ]
          });
        }
      }
      unexpected.add('${request.method} ${request.url}');
      throw StateError(unexpected.last);
    });
    final service = ChatApiService(client: client, enableSocket: false);
    addTearDown(service.dispose);
    await service.init();
    await service.fetchHistory();
    expect(await service.sendMessage('Следующий вопрос'), isA<SendSuccess>());
    final history = await service.fetchHistory(afterLatest: true);
    expect(history, isA<FetchSuccess>());
    final messages = (history as FetchSuccess).messages;
    expect(
        messages
            .where((message) => message.isFromOperator)
            .map((message) => message.content),
        ['Ответ между отправками']);
    expect(unexpected, isEmpty);
  });

  test(
      'explicit history reload returns existing messages instead of an incremental empty result',
      () async {
    final unexpected = <String>[];
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.host == 'bm.drawbridge.kz' &&
          request.url.path == _messagesPath &&
          request.headers['authorization'] == 'Bearer fixture-token' &&
          request.url.queryParameters.length == 1 &&
          request.url.queryParameters['limit'] == '100') {
        return _json({
          'messages': [
            {'id': 10, 'content': 'Сохранённая история', 'fromMe': true},
          ]
        });
      }
      unexpected.add('${request.method} ${request.url}');
      throw StateError(unexpected.last);
    });
    final service = ChatApiService(client: client, enableSocket: false);
    addTearDown(service.dispose);
    await service.init();
    await service.fetchHistory();
    final result = await service.fetchHistory();
    expect(result, isA<FetchSuccess>());
    expect((result as FetchSuccess).messages.single.content,
        'Сохранённая история');
    expect(unexpected, isEmpty);
  });

  test(
      'malformed successful history cannot masquerade as an empty conversation',
      () async {
    final unexpected = <String>[];
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.host == 'bm.drawbridge.kz' &&
          request.url.path == _messagesPath &&
          request.headers['authorization'] == 'Bearer fixture-token' &&
          request.url.queryParameters.length == 1 &&
          request.url.queryParameters['limit'] == '100') {
        return _json({'messages': null});
      }
      unexpected.add('${request.method} ${request.url}');
      throw StateError(unexpected.last);
    });
    final service = ChatApiService(client: client, enableSocket: false);
    addTearDown(service.dispose);
    await service.init();
    expect(await service.fetchHistory(), isA<FetchFailure>());
    expect(unexpected, isEmpty);
  });

  test('account switch cannot restore or expose another account history',
      () async {
    SharedPreferences.setMockInitialValues({
      'chat_widget_session': jsonEncode({
        'identity': 'user-a',
        'id': 'fixture-session',
        'token': 'fixture-token',
      }),
    });
    final oldReply = Completer<http.Response>();
    final requested = Completer<void>();
    final unexpected = <String>[];
    final client = MockClient((request) {
      if (request.method == 'GET' &&
          request.url.host == 'bm.drawbridge.kz' &&
          request.url.path == _messagesPath &&
          request.headers['authorization'] == 'Bearer fixture-token' &&
          request.url.queryParameters.length == 1 &&
          request.url.queryParameters['limit'] == '100') {
        requested.complete();
        return oldReply.future;
      }
      unexpected.add('${request.method} ${request.url}');
      throw StateError(unexpected.last);
    });
    final service = ChatApiService(client: client, enableSocket: false);
    addTearDown(service.dispose);
    await service.init(identity: 'user-a');
    final pending = service.fetchHistory();
    await requested.future;
    await service.init(identity: 'user-b');
    expect(service.hasSession, isFalse);
    expect(await ChatApiService.ownsSession('fixture-session', 'user-b'), isFalse);
    expect(await service.sendMessage('Другой аккаунт'), isA<SendFailure>());
    oldReply.complete(_json({
      'messages': [
        {'id': 11, 'content': 'Частный ответ A', 'fromMe': true},
      ],
    }));
    expect(await pending, isA<FetchFailure>());
    expect((await SharedPreferences.getInstance()).getString('chat_widget_session'),
        isNull);
    expect(unexpected, isEmpty);
  });

  test('unowned device-wide legacy chat is discarded rather than reassigned',
      () async {
    SharedPreferences.setMockInitialValues({
      'chat_widget_session': jsonEncode({
        'id': 'fixture-session',
        'token': 'fixture-token',
      }),
    });
    final requests = <String>[];
    final service = ChatApiService(
      enableSocket: false,
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url}');
        throw StateError(requests.last);
      }),
    );
    addTearDown(service.dispose);
    await service.init(identity: 'user-b');
    expect(service.hasSession, isFalse);
    expect(await service.fetchHistory(), isA<FetchFailure>());
    expect(requests, isEmpty);
  });

  test('a repeated message ID is returned once by incremental delivery',
      () async {
    final unexpected = <String>[];
    final service = ChatApiService(
      enableSocket: false,
      client: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.host == 'bm.drawbridge.kz' &&
            request.url.path == _messagesPath &&
            request.headers['authorization'] == 'Bearer fixture-token' &&
            request.url.queryParameters['limit'] == '100' &&
            request.url.queryParameters.keys
                .every((key) => {'limit', 'afterId'}.contains(key))) {
          return _json({
            'messages': [
              {'id': 11, 'content': 'Один ответ', 'fromMe': true},
              {'id': 11, 'content': 'Один ответ', 'fromMe': true},
            ],
          });
        }
        unexpected.add('${request.method} ${request.url}');
        throw StateError(unexpected.last);
      }),
    );
    addTearDown(service.dispose);
    await service.init();
    final first = await service.fetchHistory(afterLatest: true) as FetchSuccess;
    final second = await service.fetchHistory(afterLatest: true) as FetchSuccess;
    final reload = await service.fetchHistory() as FetchSuccess;
    expect(first.messages.map((message) => message.content), ['Один ответ']);
    expect(second.messages, isEmpty);
    expect(reload.messages.map((message) => message.content), ['Один ответ']);
    expect(unexpected, isEmpty);
  });
}
