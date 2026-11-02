import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/pages/profile_setup_page.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _name = ValueKey('profile-setup-name');
const _save = ValueKey('profile-setup-save');

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

Future<void> _pumpProfile(
  WidgetTester tester, {
  required ThemeData theme,
  required Map<String, dynamic> user,
  required Future<void> Function(Map<String, dynamic>?) onCompleted,
  double scale = 1,
  double keyboard = 0,
}) async {
  await tester.binding.setSurfaceSize(const Size(320, 812));
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: child!,
    ),
    home: ProfileSetupPage(initialUser: user, onCompleted: onCompleted),
  ));
  await tester.pump();
}

class _ProfileSessionFixture {
  final unexpected = <String>[];
  final updates = <({String? authorization, Object? body})>[];
  final reads = <String?>[];
  Future<http.Response>? update;
  Future<http.Response>? fullInfo;

  late final client = MockClient((request) async {
    if (request.url.origin == 'https://njt25.naliv.kz' &&
        request.url.queryParameters.isEmpty &&
        request.url.fragment.isEmpty &&
        {
          'Bearer profile-owner-a',
          'Bearer profile-owner-b',
        }.contains(request.headers['authorization'])) {
      if (request.method == 'PATCH' &&
          request.url.path == '/api/users/profile') {
        final body = jsonDecode(request.body);
        if (body is Map &&
            body.length == 5 &&
            body['name'] == 'Alice Draft' &&
            body['first_name'] == 'Alice' &&
            body['last_name'] == 'Draft' &&
            body['date_of_birth'] == '1990-01-02' &&
            body['sex'] == 0) {
          updates.add((
            authorization: request.headers['authorization'],
            body: body,
          ));
          return update ??
              _json({'success': false, 'message': 'fixture-refused'},
                  status: 409);
        }
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/auth/full-info' &&
          request.body.isEmpty) {
        reads.add(request.headers['authorization']);
        return fullInfo ??
            _json({
              'success': true,
              'data': {
                'user': {
                  'id': 'user-b',
                  'name': 'Bob',
                  'date_of_birth': '1991-01-02',
                },
              },
            });
      }
    }
    unexpected.add('${request.method} ${request.url} ${request.body}');
    throw StateError(unexpected.last);
  });

  void dispose() {
    client.close();
    expect(unexpected, isEmpty);
  }
}

Future<void> _submitSessionDraft(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(_save));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(_save));
  for (var turn = 0; turn < 8; turn++) {
    await tester.pump();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'});
  });

  testWidgets(
      'account A profile draft cannot submit with account B credentials',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _ProfileSessionFixture();
    addTearDown(fixture.dispose);
    await AuthService.saveToken('profile-owner-a');
    var completions = 0;
    await http.runWithClient(() async {
      await _pumpProfile(
        tester,
        theme: AppTheme.dark(),
        user: {'name': 'Alice Draft', 'date_of_birth': '1990-01-02'},
        onCompleted: (_) async => completions++,
      );
      await AuthService.saveToken('profile-owner-b');
      await tester.pump();
      await _submitSessionDraft(tester);
      await tester.pumpAndSettle();

      expect(fixture.updates, isEmpty);
      expect(completions, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => fixture.client);
  });

  testWidgets('late profile update cannot refetch or complete another session',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _ProfileSessionFixture();
    addTearDown(fixture.dispose);
    final update = Completer<http.Response>();
    fixture.update = update.future;
    await AuthService.saveToken('profile-owner-a');
    var completions = 0;
    await http.runWithClient(() async {
      await _pumpProfile(
        tester,
        theme: AppTheme.dark(),
        user: {'name': 'Alice Draft', 'date_of_birth': '1990-01-02'},
        onCompleted: (_) async => completions++,
      );
      await _submitSessionDraft(tester);
      expect(fixture.updates, hasLength(1));
      expect(fixture.updates.single.authorization, 'Bearer profile-owner-a');
      await AuthService.saveToken('profile-owner-b');
      update.complete(_json({'success': true}));
      await tester.pumpAndSettle();

      expect(fixture.reads, isEmpty);
      expect(completions, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => fixture.client);
  });

  testWidgets('late profile refetch cannot complete account B login',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _ProfileSessionFixture();
    addTearDown(fixture.dispose);
    final info = Completer<http.Response>();
    fixture.update = Future.value(_json({'success': true}));
    fixture.fullInfo = info.future;
    await AuthService.saveToken('profile-owner-a');
    var completions = 0;
    await http.runWithClient(() async {
      await _pumpProfile(
        tester,
        theme: AppTheme.dark(),
        user: {'name': 'Alice Draft', 'date_of_birth': '1990-01-02'},
        onCompleted: (_) async => completions++,
      );
      await _submitSessionDraft(tester);
      expect(fixture.reads, ['Bearer profile-owner-a']);
      await AuthService.saveToken('profile-owner-b');
      info.complete(_json({
        'success': true,
        'data': {
          'user': {
            'id': 'user-a',
            'name': 'Alice Draft',
            'date_of_birth': '1990-01-02',
          },
        },
      }));
      await tester.pumpAndSettle();

      expect(completions, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => fixture.client);
  });

  test(
      'profile completion gate accepts supported birthday keys only when filled',
      () {
    expect(ProfileSetupPage.isRequiredFor(null), isFalse);
    expect(ProfileSetupPage.isRequiredFor({}), isFalse);
    for (final key in [
      'date_of_birth',
      'dateOfBirth',
      'birth_date',
      'birthDate',
    ]) {
      expect(
        ProfileSetupPage.isRequiredFor({
          'user': {'name': 'Иван', key: '1980-01-01'},
        }),
        isFalse,
      );
      expect(
        ProfileSetupPage.isRequiredFor({
          'user': {'name': ' null ', key: '1980-01-01'},
        }),
        isTrue,
      );
      expect(
        ProfileSetupPage.isRequiredFor({
          'user': {'name': 'Иван', key: '  '},
        }),
        isTrue,
      );
    }
  });

  testWidgets(
      'invalid name, missing birthday and underage birthday cannot submit',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final unexpected = <http.Request>[];
    final client = MockClient((request) async {
      unexpected.add(request);
      throw StateError('Unexpected request: $request');
    });
    var completions = 0;
    await http.runWithClient(() async {
      await _pumpProfile(
        tester,
        theme: AppTheme.light(),
        user: {},
        onCompleted: (_) async => completions++,
      );
      await tester.tap(find.byKey(_save));
      await tester.pumpAndSettle();
      expect(find.text('Введите имя'), findsOneWidget);

      await tester.enterText(find.byKey(_name), 'Я');
      await tester.tap(find.byKey(_save));
      await tester.pumpAndSettle();
      expect(find.text('Имя слишком короткое'), findsOneWidget);

      await tester.enterText(find.byKey(_name), 'Иван');
      await tester.tap(find.byKey(_save));
      await tester.pumpAndSettle();
      expect(find.text('Укажите дату рождения.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());

      final now = DateTime.now();
      await _pumpProfile(
        tester,
        theme: AppTheme.dark(),
        user: {
          'name': 'Иван',
          'date_of_birth':
              DateTime(now.year - 17, now.month, now.day).toIso8601String(),
        },
        onCompleted: (_) async => completions++,
      );
      await tester.tap(find.byKey(_save));
      await tester.pumpAndSettle();
      expect(find.text('Сервис доступен только пользователям 18+.'),
          findsOneWidget);
      expect(completions, 0);
      expect(unexpected, isEmpty);
    }, () => client);
  });

  testWidgets('large-text keyboard form retains a refused draft and can retry',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final refused = Completer<http.Response>();
      final requests = <http.Request>[];
      final unexpected = <http.Request>[];
      Map<String, dynamic>? refreshed;
      var completions = 0;
      var writes = 0;
      final client = MockClient((request) async {
        if (request.url.host != 'njt25.naliv.kz' ||
            request.headers['authorization'] != 'Bearer fixture-only') {
          unexpected.add(request);
          throw StateError('Unexpected request: $request');
        }
        requests.add(request);
        if (request.method == 'PATCH' &&
            request.url.path == '/api/users/profile' &&
            request.url.queryParameters.isEmpty) {
          writes++;
          if (writes == 1) return refused.future;
          return _json({'success': true});
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/auth/full-info' &&
            request.url.queryParameters.isEmpty) {
          return _json({
            'success': true,
            'data': {
              'user': {'name': 'Иван Иванов', 'date_of_birth': '1980-01-02'},
            },
          });
        }
        unexpected.add(request);
        throw StateError('Unexpected request: $request');
      });
      await http.runWithClient(() async {
        await _pumpProfile(
          tester,
          theme: theme,
          user: {'date_of_birth': '1980-01-02', 'sex': 2},
          scale: 2,
          keyboard: 300,
          onCompleted: (info) async {
            refreshed = info;
            completions++;
          },
        );
        await tester
            .ensureVisible(find.byKey(const ValueKey('profile-setup-sex')));
        await tester.tap(find.byKey(const ValueKey('profile-setup-sex')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Мужской').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(_name), '  Иван   Иванов  ');
        await tester.ensureVisible(find.byKey(_save));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(_save));
        await tester.pump();
        await tester.pump();
        await tester.tap(find.byKey(_save));
        await tester.pump();
        expect(writes, 1);
        refused.complete(_json({'success': false, 'message': 'fixture-refused'},
            status: 409));
        await tester.pumpAndSettle();
        expect(find.text('fixture-refused'), findsOneWidget);
        expect(tester.widget<TextFormField>(find.byKey(_name)).controller!.text,
            '  Иван   Иванов  ');
        expect(completions, 0);
        expect(writes, 1);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(_save));
        await tester.tap(find.byKey(_save));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(completions, 1);
        expect(refreshed?['user']['name'], 'Иван Иванов');
        expect(writes, 2);
        expect(jsonDecode(requests.first.body), {
          'name': 'Иван   Иванов',
          'first_name': 'Иван',
          'last_name': 'Иванов',
          'date_of_birth': '1980-01-02',
          'sex': 1,
        });
        expect(unexpected, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    }
  });
}
