import 'dart:async';
import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/certificates/certificate_purchase_session.dart';
import 'package:naliv_delivery/features/certificates/ui/certificate_purchase_sheet.dart';
import 'package:naliv_delivery/features/checkout/ui/payment_success_page.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import 'package:naliv_delivery/pages/payment_method_page.dart';
import 'package:naliv_delivery/pages/profile_cards_page.dart';
import 'package:naliv_delivery/pages/profile_setup_page.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fixturePhone = '+77000000000';
const _fixtureCode = '123456';
const _expiredToken = 'fixture-expired';
const _freshToken = 'fixture-reauthenticated';
const _draftAmount = '7777,25';
const _draftRecipient = '77000000000';
const _draftMessage = 'Синтетический подарок';

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

class _ReauthenticationFixture {
  _ReauthenticationFixture({this.profileRequired = false});

  final bool profileRequired;
  final rejected = <String>[];
  int cardReads = 0;
  int verifications = 0;
  int profileWrites = 0;
  int payments = 0;
  int purchases = 0;
  bool failFirstSavedProfileRead = false;
  bool pendingPurchase = false;
  bool accountUnavailable = false;
  Completer<http.Response>? verification;

  late final MockClient client = MockClient(_respond);

  Never _reject(http.Request request) {
    final message =
        'Rejected fixture request: ${request.method} ${request.url}';
    rejected.add(message);
    throw StateError(message);
  }

  void _body(http.Request request, Map<String, Object> expected) {
    try {
      expectSync(jsonDecode(request.body), expected);
    } catch (error) {
      final message = 'Rejected fixture body: ${request.body}; $error';
      rejected.add(message);
      throw StateError(message);
    }
  }

  http.Response verified() => _json({
        'success': true,
        'data': {'token': _freshToken},
      }, status: 202);

  Future<http.Response> _respond(http.Request request) async {
    if (request.url.origin != 'https://njt25.naliv.kz' ||
        request.url.fragment.isNotEmpty ||
        request.url.userInfo.isNotEmpty) {
      _reject(request);
    }
    final path = request.url.path;
    final authorization = request.headers['authorization'];
    if (request.method == 'POST' &&
        request.url.queryParameters.isEmpty &&
        authorization == null) {
      if (path == '/api/auth/send-code') {
        _body(request, {'phone_number': _fixturePhone});
        return _json({'success': true});
      }
      if (path == '/api/auth/verify-code') {
        _body(request, {
          'phone_number': _fixturePhone,
          'onetime_code': _fixtureCode,
        });
        verifications++;
        if (verification != null) return verification!.future;
        return verified();
      }
    }
    if (authorization != 'Bearer $_expiredToken' &&
        authorization != 'Bearer $_freshToken') {
      _reject(request);
    }
    if (request.method == 'GET' && path == '/api/user/cards') {
      if (request.url.queryParameters.length != 1 ||
          request.url.queryParameters['source'] != 'halyk') {
        _reject(request);
      }
      cardReads++;
      if (authorization == 'Bearer $_expiredToken') {
        return _json({'success': false}, status: 401);
      }
      return _json({
        'success': true,
        'data': {
          'cards': [
            {'halyk_id': 'fixture-card', 'card_mask': '**** **** **** 4444'},
          ],
        },
      });
    }
    if (authorization != 'Bearer $_freshToken') {
      _reject(request);
    }
    if (request.url.queryParameters.isNotEmpty) _reject(request);
    if (request.method == 'GET' && path == '/api/auth/full-info') {
      if (accountUnavailable) {
        return _json({'success': false}, status: 503);
      }
      if (profileWrites > 0 && failFirstSavedProfileRead) {
        failFirstSavedProfileRead = false;
        return _json({'success': false}, status: 503);
      }
      return _json({
        'success': true,
        'data': {
          'user': {
            'id': 'fixture-user',
            'name': profileRequired && profileWrites == 0
                ? ''
                : 'Тестовый Получатель',
            'date_of_birth': profileRequired && profileWrites == 0
                ? ''
                : '${DateTime.now().year - 25}-01-01',
          },
        },
      });
    }
    if (request.method == 'PATCH' && path == '/api/users/profile') {
      if (!profileRequired) _reject(request);
      _body(request, {
        'name': 'Тестовый Получатель',
        'first_name': 'Тестовый',
        'last_name': 'Получатель',
        'date_of_birth': '${DateTime.now().year - 25}-01-01',
        'sex': 0,
      });
      profileWrites++;
      return _json({'success': true});
    }
    if (request.method == 'POST' &&
        path == '/api/orders/fixture-order-902/pay') {
      _body(request, {'payment_type': 'card', 'card_id': 'fixture-card'});
      payments++;
      return _json({
        'success': false,
        'error': 'fixture-refused',
        'data': {'payment_status': 'declined'},
      }, status: 402);
    }
    if (request.method == 'POST' && path == '/api/certificates/purchase') {
      _body(request, {
        'amount': 7777.25,
        'payment_type': 'card',
        'halyk_card_id': 'fixture-card',
        'recipient_login': _draftRecipient,
        'message': _draftMessage,
      });
      purchases++;
      return pendingPurchase
          ? _json({
              'success': true,
              'data': {
                'purchase_id': 'fixture-purchase-301',
                'payment_status': 'pending',
              },
            })
          : _json({'success': false, 'error': 'fixture-refused'}, status: 409);
    }
    _reject(request);
  }
}

enum _Consumer { cards, payment, certificate }

Finder _consumerFinder(_Consumer consumer) => switch (consumer) {
      _Consumer.cards => find.byType(ProfileCardsPage),
      _Consumer.payment => find.byType(PaymentMethodPage),
      _Consumer.certificate => find.byType(CertificatePurchaseSheet),
    };

class _OpenedConsumer {
  _OpenedConsumer(this.state, this.route);

  final State<StatefulWidget> state;
  final ModalRoute<dynamic> route;
}

Future<_OpenedConsumer> _openConsumer(
  WidgetTester tester,
  _Consumer consumer, {
  CertificatePurchaseSession? session,
  CartProvider? cart,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  final app = MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Builder(
          builder: (context) => FilledButton(
                key: const ValueKey('open-existing-consumer'),
                onPressed: () {
                  if (consumer == _Consumer.certificate) {
                    showCertificatePurchase(context, session: session!);
                  } else {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => consumer == _Consumer.cards
                          ? const ProfileCardsPage()
                          : const PaymentMethodPage(orderData: {
                              'order_id': 'fixture-order-902',
                              'payable_amount': 1200,
                            }),
                    ));
                  }
                },
                child: const Text('Открыть существующую форму'),
              )),
    ),
  );
  await tester.pumpWidget(cart == null
      ? app
      : ChangeNotifierProvider<CartProvider>.value(value: cart, child: app));
  await _tap(tester, 'open-existing-consumer');
  final finder = _consumerFinder(consumer);
  return _OpenedConsumer(
    tester.state(finder),
    ModalRoute.of(tester.element(finder))!,
  );
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _requestFixtureCode(WidgetTester tester) async {
  await _tap(tester, 'card-sign-in');
  await tester.enterText(
      find.byKey(const ValueKey('auth-phone-input')), _fixturePhone);
  await _tap(tester, 'request-code-button');
}

Future<void> _verifyFixtureCode(WidgetTester tester) async {
  await _requestFixtureCode(tester);
  final semantics = tester.ensureSemantics();
  await tester.pump();
  expect(
      tester
          .getSemantics(find.byKey(const ValueKey('auth-code-input')))
          .getSemanticsData()
          .hasAction(SemanticsAction.setText),
      isTrue);
  semantics.dispose();
  await tester.enterText(
      find.byKey(const ValueKey('auth-code-input')), _fixtureCode);
  await tester.pumpAndSettle();
}

Future<void> _fillCertificateDraft(WidgetTester tester) async {
  for (final entry in {
    'certificate-purchase-amount': _draftAmount,
    'certificate-purchase-recipient': _draftRecipient,
    'certificate-purchase-message': _draftMessage,
  }.entries) {
    await tester.enterText(find.byKey(ValueKey(entry.key)), entry.value);
  }
  await tester.pump();
}

void _expectCertificateDraft(
    WidgetTester tester, CertificatePurchaseSession session) {
  expect(session.amountText, _draftAmount);
  expect(session.recipientLogin, _draftRecipient);
  expect(session.message, _draftMessage);
  for (final entry in {
    'certificate-purchase-amount': _draftAmount,
    'certificate-purchase-recipient': _draftRecipient,
    'certificate-purchase-message': _draftMessage,
  }.entries) {
    expect(
        tester
            .widget<TextField>(find.byKey(ValueKey(entry.key)))
            .controller!
            .text,
        entry.value);
  }
}

void _expectRetained(
    WidgetTester tester, _Consumer consumer, _OpenedConsumer opened) {
  final finder = _consumerFinder(consumer);
  expect(find.byType(LoginPage), findsNothing);
  expect(tester.state(finder), same(opened.state));
  expect(ModalRoute.of(tester.element(finder)), same(opened.route));
  expect(opened.route.isCurrent, isTrue);
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'auth_token': _expiredToken});
  });

  testWidgets(
      'reauthentication returns to the same saved-card route, not a binding success',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _ReauthenticationFixture();
    await http.runWithClient(() async {
      final opened = await _openConsumer(tester, _Consumer.cards);
      await _verifyFixtureCode(tester);
      _expectRetained(tester, _Consumer.cards, opened);
      expect(find.byKey(const ValueKey('saved-card-fixture-card')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('card-sign-in')), findsNothing);
      expect(
          find.text('Новая карта сохранена и готова к оплате'), findsNothing);
      expect(fixture.cardReads, 2);
      expect(fixture.verifications, 1);
      expect(fixture.rejected, isEmpty);
      await _dispose(tester);
    }, () => fixture.client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
      'payment reauthentication retains the order and unrelated cart before a real retry',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _ReauthenticationFixture();
    final cart = CartProvider();
    await cart.bindBusiness(1);
    cart.addItem(CartItem(
      itemId: 83,
      name: 'Другой товар',
      price: 1000,
      quantity: 2,
      stepQuantity: 1,
      selectedVariants: [],
      promotions: [],
    ));
    addTearDown(cart.dispose);
    await http.runWithClient(() async {
      final opened = await _openConsumer(tester, _Consumer.payment, cart: cart);
      await _verifyFixtureCode(tester);
      _expectRetained(tester, _Consumer.payment, opened);
      expect(find.byKey(const ValueKey('payment-card-fixture-card')),
          findsOneWidget);
      expect(fixture.payments, 0);
      await tester.pump(const Duration(seconds: 5));
      await _tap(tester, 'pay-order-button');
      expect(fixture.payments, 1);
      expect(find.byType(PaymentSuccessPage), findsNothing);
      expect(cart.items.single.itemId, 83);
      expect(cart.items.single.quantity, 2);
      expect(fixture.rejected, isEmpty);
      await _dispose(tester);
    }, () => fixture.client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
      'certificate reauthentication preserves the original sheet and submitted draft',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _ReauthenticationFixture();
    final session = CertificatePurchaseSession();
    addTearDown(session.dispose);
    await http.runWithClient(() async {
      final opened =
          await _openConsumer(tester, _Consumer.certificate, session: session);
      await _fillCertificateDraft(tester);
      await _verifyFixtureCode(tester);
      _expectRetained(tester, _Consumer.certificate, opened);
      _expectCertificateDraft(tester, session);
      expect(session.selectedCardId, 'fixture-card');
      expect(fixture.purchases, 0);
      await _tap(tester, 'certificate-purchase-submit');
      expect(fixture.purchases, 1);
      expect(session.completed, isFalse);
      expect(session.purchaseId, isNull);
      _expectCertificateDraft(tester, session);
      expect(fixture.rejected, isEmpty);
      await _dispose(tester);
    }, () => fixture.client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  for (final consumer in _Consumer.values) {
    testWidgets(
        'cancelled sign-in keeps the $consumer route without a card refresh',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = _ReauthenticationFixture();
      final session = CertificatePurchaseSession();
      addTearDown(session.dispose);
      await http.runWithClient(() async {
        final opened = await _openConsumer(tester, consumer, session: session);
        if (consumer == _Consumer.certificate) {
          await _fillCertificateDraft(tester);
        }
        await _requestFixtureCode(tester);
        await tester.tap(find.byTooltip('Назад'));
        await tester.pumpAndSettle();
        _expectRetained(tester, consumer, opened);
        expect(find.byKey(const ValueKey('card-sign-in')), findsOneWidget);
        expect(fixture.cardReads, 1);
        expect(fixture.verifications, 0);
        if (consumer == _Consumer.certificate) {
          _expectCertificateDraft(tester, session);
        }
        expect(fixture.rejected, isEmpty);
        await _dispose(tester);
      }, () => fixture.client);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets(
      'required name and birthday complete on the login route before the draft resumes',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _ReauthenticationFixture(profileRequired: true)
      ..failFirstSavedProfileRead = true;
    final session = CertificatePurchaseSession();
    addTearDown(session.dispose);
    await http.runWithClient(() async {
      final opened =
          await _openConsumer(tester, _Consumer.certificate, session: session);
      await _fillCertificateDraft(tester);
      await _verifyFixtureCode(tester);
      expect(find.byType(ProfileSetupPage), findsOneWidget);
      expect(opened.state.mounted, isTrue);
      expect(fixture.cardReads, 1);
      expect(fixture.purchases, 0);
      await tester.enterText(find.byKey(const ValueKey('profile-setup-name')),
          'Тестовый Получатель');
      await _tap(tester, 'profile-setup-birthday');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await _tap(tester, 'profile-setup-save');
      expect(find.byType(ProfileSetupPage), findsOneWidget);
      expect(fixture.cardReads, 1);
      expect(
          tester
              .widget<TextFormField>(
                  find.byKey(const ValueKey('profile-setup-name')))
              .controller!
              .text,
          'Тестовый Получатель');
      await _tap(tester, 'profile-setup-save');
      _expectRetained(tester, _Consumer.certificate, opened);
      _expectCertificateDraft(tester, session);
      expect(find.byType(ProfileSetupPage), findsNothing);
      expect(fixture.profileWrites, 2);
      expect(fixture.cardReads, 2);
      expect(fixture.purchases, 0);
      expect(fixture.rejected, isEmpty);
      await _dispose(tester);
    }, () => fixture.client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
      'cancelling the required-profile gate retains the certificate draft without refresh',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _ReauthenticationFixture(profileRequired: true);
    final session = CertificatePurchaseSession();
    addTearDown(session.dispose);
    await http.runWithClient(() async {
      final opened =
          await _openConsumer(tester, _Consumer.certificate, session: session);
      await _fillCertificateDraft(tester);
      await _verifyFixtureCode(tester);
      expect(find.byType(ProfileSetupPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      _expectRetained(tester, _Consumer.certificate, opened);
      _expectCertificateDraft(tester, session);
      expect(find.byKey(const ValueKey('card-sign-in')), findsOneWidget);
      expect(fixture.cardReads, 1);
      expect(fixture.profileWrites, 0);
      expect(fixture.purchases, 0);
      expect(fixture.rejected, isEmpty);
      await _dispose(tester);
    }, () => fixture.client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
      'an unreadable fresh account cannot return authenticated card success',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _ReauthenticationFixture()..accountUnavailable = true;
    await http.runWithClient(() async {
      final opened = await _openConsumer(tester, _Consumer.cards);
      await _verifyFixtureCode(tester);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(opened.state.mounted, isTrue);
      expect(fixture.cardReads, 1);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      _expectRetained(tester, _Consumer.cards, opened);
      expect(
          find.byKey(const ValueKey('saved-card-fixture-card')), findsNothing);
      expect(fixture.cardReads, 1);
      expect(fixture.rejected, isEmpty);
      await _dispose(tester);
    }, () => fixture.client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
      'cancelled in-flight verification cannot pop the original consumer or refresh it',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _ReauthenticationFixture()
      ..verification = Completer<http.Response>();
    await http.runWithClient(() async {
      final opened = await _openConsumer(tester, _Consumer.cards);
      await _requestFixtureCode(tester);
      await tester.enterText(
          find.byKey(const ValueKey('auth-code-input')), _fixtureCode);
      await tester.pump();
      await tester.pump();
      expect(fixture.verifications, 1);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      fixture.verification!.complete(fixture.verified());
      await tester.pumpAndSettle();
      _expectRetained(tester, _Consumer.cards, opened);
      expect(
          find.byKey(const ValueKey('saved-card-fixture-card')), findsNothing);
      expect(find.byKey(const ValueKey('card-sign-in')), findsOneWidget);
      expect(fixture.cardReads, 1);
      expect(fixture.rejected, isEmpty);
      await _dispose(tester);
    }, () => fixture.client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
      'unresolved certificate purchase never exposes reauthentication that can unlock it',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _ReauthenticationFixture()..pendingPurchase = true;
    final session = CertificatePurchaseSession()
      ..amountText = _draftAmount
      ..recipientLogin = _draftRecipient
      ..message = _draftMessage
      ..selectedCardId = 'fixture-card';
    addTearDown(session.dispose);
    await http.runWithClient(() async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('auth_token', _freshToken);
      await session.purchase();
      await preferences.setString('auth_token', _expiredToken);
      await _openConsumer(tester, _Consumer.certificate, session: session);
      expect(session.unconfirmed, isTrue);
      expect(session.purchaseId, 'fixture-purchase-301');
      _expectCertificateDraft(tester, session);
      expect(find.byKey(const ValueKey('certificate-cards-error')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('card-sign-in')), findsNothing);
      expect(find.byKey(const ValueKey('certificate-purchase-submit')),
          findsNothing);
      expect(fixture.purchases, 1);
      expect(fixture.verifications, 0);
      expect(fixture.rejected, isEmpty);
      await _dispose(tester);
    }, () => fixture.client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
