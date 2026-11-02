import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/utils/financial_operation_journal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('verified intent survives preferences cache and owner recreation',
      () async {
    final journal = FinancialOperationJournal(
        'restart-account', FinancialOperationKind.orderCreation);
    expect(
        await journal.reserve({
          'total_amount': 1030,
          'items': [99]
        }),
        isTrue);
    journal.release();
    SharedPreferences.resetStatic();
    final restored = FinancialOperationJournal(
        'restart-account', FinancialOperationKind.orderCreation);
    final state = await restored.read();
    expect(state.ready, isFalse);
    expect(state.intent!.request, {
      'total_amount': 1030,
      'items': [99]
    });
    expect(await restored.reserve({'total_amount': 2030}), isFalse);
  });

  test('rejected first write never reserves a financial mutation', () async {
    final journal = FinancialOperationJournal(
        'write-refused-account', FinancialOperationKind.certificatePurchase);
    final store = OnboardingPreferences()..install();
    store.rejectedKeys.add(journal.preferenceKey);
    expect(await journal.reserve({'amount': 10000}), isFalse);
    expect((await journal.read()).ready, isTrue);
  });

  test('corrupt journal values fail closed without overwriting evidence',
      () async {
    for (final raw in [
      '{corrupt',
      jsonEncode({'version': 2, 'state': 'unresolved', 'request': {}}),
      jsonEncode({'version': 1, 'state': 'ready', 'request': {}}),
      jsonEncode({'version': 1, 'state': 'unresolved', 'request': []}),
    ]) {
      final journal = FinancialOperationJournal(
          'corrupt-account', FinancialOperationKind.orderCreation);
      SharedPreferences.setMockInitialValues({journal.preferenceKey: raw});
      final state = await journal.read();
      expect(state.storageUnavailable, isTrue);
      expect(await journal.reserve({'total_amount': 100}), isFalse);
      expect((await SharedPreferences.getInstance()).get(journal.preferenceKey),
          raw);
    }
  });

  test('account and financial-kind reservations are isolated', () async {
    final a = FinancialOperationJournal(
        'isolation-a', FinancialOperationKind.orderCreation);
    final b = FinancialOperationJournal(
        'isolation-b', FinancialOperationKind.orderCreation);
    final certificate = FinancialOperationJournal(
        'isolation-a', FinancialOperationKind.certificatePurchase);
    expect(await a.reserve({'total_amount': 100}), isTrue);
    expect(await b.reserve({'total_amount': 200}), isTrue);
    expect(await certificate.reserve({'amount': 10000}), isTrue);
    a.release();
    b.release();
    certificate.release();
    expect((await a.read()).intent!.request['total_amount'], 100);
    expect((await b.read()).intent!.request['total_amount'], 200);
    expect((await certificate.read()).intent!.request['amount'], 10000);
  });

  test(
      'refused identity update retains known identity and durable unresolved intent',
      () async {
    final journal = FinancialOperationJournal(
        'late-identity-account', FinancialOperationKind.certificatePurchase);
    final store = OnboardingPreferences()..install();
    expect(await journal.reserve({'amount': 10000}), isTrue);
    store.rejectedKeys.add(journal.preferenceKey);
    expect(
        await journal.settle(
          outcome: FinancialOperationOutcome.unknown,
          identity: 'retained-server-purchase',
        ),
        isFalse);
    journal.release();
    final restored = FinancialOperationJournal(
        'late-identity-account', FinancialOperationKind.certificatePurchase);
    expect(
        (await restored.read()).intent!.identity, 'retained-server-purchase');
    final raw = (await SharedPreferences.getInstance())
        .getString(journal.preferenceKey)!;
    expect((jsonDecode(raw) as Map)['state'], 'unresolved');
    expect(await restored.reserve({'amount': 20000}), isFalse);
  });

  test('unknown cannot be acknowledged as if definitively refused', () async {
    final journal = FinancialOperationJournal(
        'unknown-account', FinancialOperationKind.orderCreation);
    expect(await journal.reserve({'total_amount': 1030}), isTrue);
    await journal.settle(outcome: FinancialOperationOutcome.unknown);
    expect(await journal.acknowledge(), isFalse);
    journal.release();
    expect((await journal.read()).ready, isFalse);
  });

  test('definite refusal unlocks only after checked removal', () async {
    final journal = FinancialOperationJournal(
        'refusal-account', FinancialOperationKind.orderCreation);
    expect(await journal.reserve({'total_amount': 1030}), isTrue);
    expect(await journal.settle(outcome: FinancialOperationOutcome.refused),
        isTrue);
    journal.release();
    expect((await journal.read()).ready, isTrue);
  });

  for (final status in [408, 500, 503]) {
    test('HTTP $status overrides accepted-looking financial payload', () {
      expect(
          financialOperationOutcome({
            'success': true,
            'statusCode': status,
          }, accepted: true),
          FinancialOperationOutcome.unknown);
    });
  }

  test(
      'completed certificate evidence survives later unknown and refusal results',
      () async {
    final journal = FinancialOperationJournal(
        'terminal-account', FinancialOperationKind.certificatePurchase);
    expect(await journal.reserve({'amount': 10000}), isTrue);
    expect(
        await journal.settle(
          outcome: FinancialOperationOutcome.accepted,
          identity: 'completed-purchase',
          result: {
            'certificate': {'code': 'SERVER-CODE'}
          },
          completed: true,
        ),
        isTrue);
    await journal.settle(
        outcome: FinancialOperationOutcome.unknown,
        result: {'payment_status': 'pending'});
    await journal.settle(outcome: FinancialOperationOutcome.refused);
    journal.release();
    final stored = await journal.read();
    expect(stored.intent!.completed, isTrue);
    expect(stored.intent!.identity, 'completed-purchase');
    expect(stored.intent!.result, {
      'certificate': {'code': 'SERVER-CODE'}
    });
    expect(await journal.reserve({'amount': 20000}), isFalse);
  });
}
