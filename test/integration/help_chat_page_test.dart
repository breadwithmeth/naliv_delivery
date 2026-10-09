import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/pages/help_chat_page.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/services/chat_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _widgetPath = '/api/widget/wgt_Ioj4vp2arln68wZeSMeyWd4l';
const _input = ValueKey('support-message-input');
const _send = ValueKey('support-send');

class _ChatFixture {
  late final http.Client client = MockClient(_respond);
  Future<http.Response> Function(http.Request)? history;
  Future<http.Response> Function(http.Request)? send;
  Future<http.Response> Function(http.Request)? session;
  final unexpected = <String>[];
  final sends = <String>[];
  final historyCursors = <String?>[];

  Future<http.Response> _respond(http.Request request) async {
    final url = request.url;
    if (url.scheme != 'https' || url.host != 'bm.drawbridge.kz') {
      return _reject(request);
    }
    if (request.method == 'GET' &&
        url.path == '$_widgetPath/config' &&
        url.queryParameters.isEmpty &&
        !request.headers.containsKey('authorization')) {
      return _json({
        'widget': {'name': 'Поддержка'}
      });
    }
    if (request.method == 'POST' &&
        url.path == '$_widgetPath/sessions' &&
        url.queryParameters.isEmpty &&
        request.body == '{}' &&
        session != null) {
      return session!(request);
    }
    if (url.path == '$_widgetPath/sessions/fixture-session/messages' &&
        request.headers['authorization'] == 'Bearer fixture-token') {
      if (request.method == 'GET' &&
          url.queryParameters['limit'] == '100' &&
          url.queryParameters.keys
              .every((key) => {'limit', 'afterId'}.contains(key))) {
        historyCursors.add(url.queryParameters['afterId']);
        if (history != null) return history!(request);
        return _json({'messages': []});
      }
      if (request.method == 'POST' &&
          url.queryParameters.isEmpty &&
          send != null) {
        final body = jsonDecode(request.body);
        if (body is Map && body.length == 1 && body['content'] is String) {
          sends.add(body['content'] as String);
          return send!(request);
        }
      }
    }
    return _reject(request);
  }

  http.Response _reject(http.Request request) {
    final message = 'Unexpected request: ${request.method} ${request.url}';
    unexpected.add(message);
    throw StateError(message);
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, Object> _message(int id, String content, {bool operator = true}) =>
    {
      'id': id,
      'content': content,
      'fromMe': operator,
    };

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'chat_widget_session': jsonEncode({
          'id': 'fixture-session',
          'identity': null,
          'token': 'fixture-token',
        }),
      }));

  Future<void> pumpChat(
    WidgetTester tester,
    _ChatFixture fixture, {
    Map<String, dynamic>? order,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 48, bottom: 34),
          viewPadding: const EdgeInsets.only(top: 48, bottom: 34),
        ),
        child: child!,
      ),
      home: HelpChatPage(
        entryPoint: order == null ? 'profile' : 'order_detail',
        order: order,
        chatService:
            ChatApiService(client: fixture.client, enableSocket: false),
      ),
    ));
    await tester.pumpAndSettle();
    addTearDown(() => expect(fixture.unexpected, isEmpty));
  }

  testWidgets(
      'failed send keeps draft and retry produces only accepted history',
      (tester) async {
    final fixture = _ChatFixture();
    var attempts = 0;
    fixture.send = (_) async => ++attempts == 1
        ? http.Response('', 503)
        : _json({'message': _message(7, 'Сохранённый вопрос', operator: false)},
            201);
    await pumpChat(tester, fixture);
    await tester.enterText(find.byKey(_input), 'Сохранённый вопрос');
    await tester.pump();
    await tester.tap(find.byKey(_send));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byKey(_input)).controller!.text,
        'Сохранённый вопрос');
    expect(find.byKey(const ValueKey('support-send-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('support-message-7')), findsNothing);
    expect(find.byKey(const ValueKey('support-empty-conversation')),
        findsOneWidget);

    await tester.tap(find.text('Повторить отправку'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-message-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('support-send-error')), findsNothing);
    expect(
        tester.widget<TextField>(find.byKey(_input)).controller!.text, isEmpty);
    expect(fixture.sends, ['Сохранённый вопрос', 'Сохранённый вопрос']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'poll failure preserves history and explicit retry reloads full history',
      (tester) async {
    final fixture = _ChatFixture();
    fixture.history =
        (request) async => request.url.queryParameters.containsKey('afterId')
            ? http.Response('', 503)
            : _json({
                'messages': [_message(1, 'Ответ из истории')]
              });
    await pumpChat(tester, fixture);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-history-error')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('support-message-1')));
    expect(find.text('Ответ из истории'), findsOneWidget);
    await tester.ensureVisible(find.text('Повторить загрузку'));
    await tester.tap(find.text('Повторить загрузку'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-history-error')), findsNothing);
    expect(fixture.historyCursors.first, isNull);
    expect(fixture.historyCursors[1], '1');
    expect(fixture.historyCursors.last, isNull);
    expect(find.byKey(const ValueKey('support-message-1')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'expired send preserves draft through explicit session reconnection',
      (tester) async {
    final fixture = _ChatFixture();
    fixture.send = (_) async => http.Response('', 401);
    fixture.session = (_) async => _json({
          'session': {'id': 'fixture-session', 'token': 'fixture-token'},
        }, 201);
    await pumpChat(tester, fixture);
    await tester.enterText(find.byKey(_input), 'Не потерять после 401');
    await tester.pump();
    await tester.tap(find.byKey(_send));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(_input)).controller!.text,
        'Не потерять после 401');
    expect(tester.widget<IconButton>(find.byKey(_send)).onPressed, isNull);
    await tester.ensureVisible(find.text('Подключиться заново'));
    await tester.tap(find.text('Подключиться заново'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(_input)).controller!.text,
        'Не потерять после 401');
    expect(tester.widget<IconButton>(find.byKey(_send)).onPressed, isNotNull);
    expect(fixture.sends, ['Не потерять после 401']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('opening an order enquiry never sends context without consent',
      (tester) async {
    final fixture = _ChatFixture();
    await pumpChat(tester, fixture, order: {'order_id': 71, 'status': 0});
    expect(find.byKey(const ValueKey('support-order-context')), findsOneWidget);
    expect(find.byKey(const ValueKey('support-empty-conversation')),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    expect(fixture.sends, isEmpty);
    expect(fixture.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('disposing during session creation cannot restart polling',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fixture = _ChatFixture();
    final response = Completer<http.Response>();
    var creating = false;
    fixture.session = (_) {
      creating = true;
      return response.future;
    };
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: HelpChatPage(
          entryPoint: 'profile',
          chatService:
              ChatApiService(client: fixture.client, enableSocket: false)),
    ));
    await tester.pump();
    await tester.pump();
    expect(creating, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(_json({
      'session': {'id': 'fixture-session', 'token': 'fixture-token'},
    }, 201));
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    expect(fixture.historyCursors, isEmpty);
    expect(fixture.unexpected, isEmpty);
  });

  testWidgets(
      'cold support click continues through login and returns to the preserved route',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'chat_widget_session': jsonEncode({
        'identity': 'user-a',
        'id': 'fixture-session',
        'token': 'fixture-token',
      }),
    });
    await AuthService.notifySessionChanged();
    final fixture = _ChatFixture();
    fixture.history = (_) async => _json({
          'messages': [_message(11, 'Подтверждённый ответ поддержки')],
        });
    final rejectedAuth = <String>[];
    final token =
        'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'user-a'}))).replaceAll('=', '')}.fixture';
    final authClient = MockClient((request) async {
      if (request.url.origin == 'https://njt25.naliv.kz' &&
          request.url.queryParameters.isEmpty &&
          request.url.fragment.isEmpty) {
        if (request.method == 'POST' &&
            request.url.path == '/api/auth/send-code' &&
            request.headers['authorization'] == null &&
            request.body == jsonEncode({'phone_number': '+77000000000'})) {
          return _json({'success': true});
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/auth/verify-code' &&
            request.headers['authorization'] == null &&
            request.body ==
                jsonEncode({
                  'phone_number': '+77000000000',
                  'onetime_code': '123456',
                })) {
          return _json({
            'success': true,
            'data': {'token': token},
          }, 202);
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/auth/full-info' &&
            request.headers['authorization'] == 'Bearer $token') {
          return _json({
            'success': true,
            'data': {
              'user': {
                'id': 'user-a',
                'name': 'Тестовый Получатель',
                'date_of_birth': '1990-01-01',
              },
            },
          });
        }
      }
      rejectedAuth.add('${request.method} ${request.url}');
      throw StateError(rejectedAuth.last);
    });
    await http.runWithClient(() async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final draft = TextEditingController(text: 'Сохранённый текст экрана');
      addTearDown(draft.dispose);
      final notifications = NotificationService.forTesting(
        navigatorKey: navigatorKey,
        resolveIdentity: ApiService.getCurrentUserExternalId,
        chatServiceFactory: () =>
            ChatApiService(client: fixture.client, enableSocket: false),
      );
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.dark(),
        home: Scaffold(
          body: TextField(key: const ValueKey('route-draft'), controller: draft),
        ),
      ));
      const payload = <String, dynamic>{
        'type': 'support_message',
        'session_id': 'fixture-session',
        'message_id': 11,
        'external_id': 'user-a',
      };
      await notifications.handleNotificationData(payload);
      expect(find.byKey(const ValueKey('route-draft')), findsOneWidget);
      final continued = notifications.resumePendingNavigation();
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('auth-phone-input')), '+77000000000');
      await tester.ensureVisible(find.byKey(const ValueKey('request-code-button')));
      await tester.tap(find.byKey(const ValueKey('request-code-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('auth-code-input')), '123456');
      await tester.pumpAndSettle();
      await continued;
      await tester.pumpAndSettle();
      expect(find.text('Подтверждённый ответ поддержки'), findsOneWidget);
      expect(fixture.sends, isEmpty);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('route-draft')), findsOneWidget);
      expect(draft.text, 'Сохранённый текст экрана');
      expect(rejectedAuth, isEmpty);
      expect(fixture.unexpected, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => authClient);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
      'support push refresh merges one message and pauses reads in background',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'chat_widget_session': jsonEncode({
        'identity': 'user-a',
        'id': 'fixture-session',
        'token': 'fixture-token',
      }),
    });
    await AuthService.bindAuthenticatedIdentity('user-a');
    final fixture = _ChatFixture();
    fixture.history = (_) async => _json({
          'messages': [
            _message(11, 'Ответ только из истории'),
            _message(11, 'Ответ только из истории'),
          ],
        });
    final navigatorKey = GlobalKey<NavigatorState>();
    final notifications = NotificationService.forTesting(
      navigatorKey: navigatorKey,
      resolveIdentity: () async => 'user-a',
      chatServiceFactory: () =>
          ChatApiService(client: fixture.client, enableSocket: false),
    );
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      theme: AppTheme.light(),
      home: const Scaffold(body: Text('Исходный экран')),
    ));
    await notifications.resumePendingNavigation();
    const payload = <String, dynamic>{
      'type': 'chat_message',
      'sessionId': 'fixture-session',
      'messageId': 11,
      'externalId': 'user-a',
      'content': 'Нельзя показывать текст push вместо истории',
    };
    await notifications.handleNotificationData(payload);
    await tester.pumpAndSettle();
    await notifications.handleNotificationData(payload, clicked: false);
    await notifications.handleNotificationData(payload);
    await tester.pumpAndSettle();
    expect(find.text('Ответ только из истории'), findsOneWidget);
    expect(find.text('Нельзя показывать текст push вместо истории'), findsNothing);
    final reads = fixture.historyCursors.length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 8));
    expect(fixture.historyCursors.length, reads);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(fixture.historyCursors.length, reads + 1);
    expect(find.text('Ответ только из истории'), findsOneWidget);
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(find.text('Исходный экран'), findsOneWidget);
    expect(fixture.sends, isEmpty);
    expect(fixture.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('account switch hides private history and refuses an old push',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'chat_widget_session': jsonEncode({
        'identity': 'user-a',
        'id': 'fixture-session',
        'token': 'fixture-token',
      }),
    });
    await AuthService.bindAuthenticatedIdentity('user-a');
    final fixture = _ChatFixture();
    fixture.history = (_) async => _json({
          'messages': [_message(11, 'Частная переписка A')],
        });
    var identity = 'user-a';
    final navigatorKey = GlobalKey<NavigatorState>();
    final notifications = NotificationService.forTesting(
      navigatorKey: navigatorKey,
      resolveIdentity: () async => identity,
      chatServiceFactory: () =>
          ChatApiService(client: fixture.client, enableSocket: false),
    );
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      theme: AppTheme.dark(),
      home: const Scaffold(body: Text('Исходный экран')),
    ));
    await notifications.resumePendingNavigation();
    const payload = <String, dynamic>{
      'type': 'support_message',
      'session_id': 'fixture-session',
      'message_id': 11,
      'external_id': 'user-a',
    };
    await notifications.handleNotificationData(payload);
    await tester.pumpAndSettle();
    expect(find.text('Частная переписка A'), findsOneWidget);
    await tester.enterText(find.byKey(_input), 'Частный черновик A');
    identity = 'user-b';
    await AuthService.bindAuthenticatedIdentity(identity);
    await tester.pumpAndSettle();
    expect(find.text('Частная переписка A'), findsNothing);
    expect(tester.widget<TextField>(find.byKey(_input)).controller!.text, isEmpty);
    expect(await ChatApiService.ownsSession('fixture-session', identity), isFalse);
    await notifications.handleNotificationData(payload);
    await tester.pumpAndSettle();
    expect(find.text('Частная переписка A'), findsNothing);
    expect(fixture.historyCursors.length, 1);
    expect(fixture.sends, isEmpty);
    expect(fixture.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('a push with a session token cannot open a private conversation',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final rejected = <String>[];
    final notifications = NotificationService.forTesting(
      navigatorKey: navigatorKey,
      resolveIdentity: () async {
        rejected.add('Unexpected authentication lookup');
        throw StateError(rejected.last);
      },
      chatServiceFactory: () {
        rejected.add('Unexpected chat creation');
        throw StateError(rejected.last);
      },
    );
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      theme: AppTheme.dark(),
      home: const Scaffold(body: Text('Исходный экран')),
    ));
    await notifications.resumePendingNavigation();
    await notifications.handleNotificationData({
      'type': 'support_message',
      'session_id': 'fixture-session',
      'message_id': 11,
      'session_token': 'untrusted-capability',
    });
    await tester.pumpAndSettle();
    expect(find.text('Исходный экран'), findsOneWidget);
    expect(rejected, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
