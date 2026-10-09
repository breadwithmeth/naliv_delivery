import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/pages/card_flow.dart';
import 'package:naliv_delivery/utils/api.dart';

const _link = AddCardLinkResult(
  success: true,
  link: 'https://fixture-bank.example/card/attach',
  message: 'Provider link',
);

Map<String, Object> _card(String id, {String mask = '**** **** **** 4444'}) =>
    {'id': id, 'mask': mask};

void main() {
  test('duplicate IDs, missing masks and PAN identities remain isolated', () {
    final collection = SavedCard.parse([
      _card('safe'),
      {'halyk_id': '4111111111111111', 'mask': '****1111'},
      _card('duplicate'),
      _card('duplicate', mask: '****4949'),
      {'id': 'missing-mask', 'mask': null},
    ]);
    expect(collection.cards.map((card) => card.chargeId),
        ['safe', null, null, null]);
    expect(collection.cards.map((card) => card.mask),
        ['**** **** **** 4444', '****1111', '**** **** **** 4444', '****4949']);
    expect(collection.cards.map((card) => card.rowKey).toSet(), hasLength(4));
    expect(collection.rejectedCount, 1);
    expect(collection.complete, isFalse);
  });

  test('provider identity wins over a local row when Halyk ID is absent', () {
    final collection = SavedCard.parse([
      {'id': 'row-a', 'card_id': 'card-a', 'mask': '****1234'},
    ]);
    expect(collection.cards.single.chargeId, 'card-a');
    expect(collection.complete, isTrue);
  });

  test('a malformed duplicate cannot hide a verified card', () {
    final collection = SavedCard.parse([
      {'halyk_id': 'bank-existing', 'card_mask': '****4444'},
      {'halyk_id': 'bank-existing', 'card_mask': null},
      {'mask': '****1234'},
      {'id': 'local', 'halyk_id': '4111111111111111', 'mask': '****1111'},
    ]);
    expect(collection.cards.map((card) => card.chargeId),
        ['bank-existing', null, null]);
    expect(collection.rejectedCount, 1);
    expect(collection.complete, isFalse);
  });

  test(
      'pending link creation suppresses duplicate requests and cancellation ignores its late result',
      () async {
    final link = Completer<AddCardLinkResult>();
    var requests = 0;
    var launches = 0;
    final flow = CardFlow(
      readCards: () async => [_card('old')],
      generateLink: () {
        requests++;
        return link.future;
      },
      openForm: (_, __) async {
        launches++;
        return CardFormOutcome.opened;
      },
    );
    addTearDown(flow.dispose);
    await flow.refresh();
    final pending = flow.addCard();
    await flow.addCard();
    expect(requests, 1);
    expect(flow.addState, CardAddState.preparing);
    flow.cancel();
    link.complete(_link);
    await pending;
    expect(launches, 0);
    expect(flow.addState, CardAddState.cancelled);
    expect(flow.newCardId, isNull);
    expect(flow.canAdd, isTrue);
  });

  test(
      'cancelled binding cannot confirm a later attempt from a cached baseline',
      () async {
    Object? response = [_card('original')];
    final flow = CardFlow(
      readCards: () async => response,
      generateLink: () async => _link,
      openForm: (_, __) async => CardFormOutcome.opened,
    );
    addTearDown(flow.dispose);
    await flow.refresh();
    await flow.addCard();
    flow.cancel();
    expect(flow.canAdd, isTrue);

    await flow.addCard();
    response = [_card('original'), _card('late-cancelled-binding')];
    await flow.refresh();
    expect(flow.cards.map((card) => card.chargeId),
        ['original', 'late-cancelled-binding']);
    expect(flow.addState, isNot(CardAddState.confirmed));
    expect(flow.newCardId, isNull);

    flow.cancel();
    await flow.refresh();
    await flow.addCard();
    response = [
      _card('original'),
      _card('late-cancelled-binding'),
      _card('fresh-binding'),
    ];
    await flow.refresh();
    expect(flow.addState, CardAddState.confirmed);
    expect(flow.newCardId, 'fresh-binding');
  });

  test('provider return and mask changes do not prove a newly bound card',
      () async {
    Object? response = [_card('old')];
    final flow = CardFlow(
      readCards: () async => response,
      generateLink: () async => _link,
      openForm: (_, __) async => CardFormOutcome.returned,
    );
    addTearDown(flow.dispose);
    await flow.refresh();
    await flow.addCard();
    expect(flow.addState, CardAddState.awaiting);
    expect(flow.newCardId, isNull);
    response = [_card('old', mask: '**** **** **** 4949')];
    await flow.refresh();
    expect(flow.addState, CardAddState.awaiting);
    expect(flow.newCardId, isNull);
  });

  test(
      'a failed refresh retains pending state and retry can confirm the new card',
      () async {
    Object? response = [_card('old')];
    final flow = CardFlow(
      readCards: () async => response,
      generateLink: () async => _link,
      openForm: (_, __) async => CardFormOutcome.opened,
    );
    addTearDown(flow.dispose);
    await flow.refresh();
    await flow.addCard();
    response = null;
    await flow.refresh();
    expect(flow.error, isNotNull);
    expect(flow.cards.single.chargeId, 'old');
    expect(flow.addState, CardAddState.awaiting);
    expect(flow.newCardId, isNull);
    response = [_card('old'), _card('new')];
    await flow.refresh();
    expect(flow.error, isNull);
    expect(flow.addState, CardAddState.confirmed);
    expect(flow.newCardId, 'new');
  });

  test('cancelled provider never confirms a later server identity', () async {
    Object? response = [_card('old')];
    final flow = CardFlow(
      readCards: () async => response,
      generateLink: () async => _link,
      openForm: (_, __) async => CardFormOutcome.cancelled,
    );
    addTearDown(flow.dispose);
    await flow.refresh();
    await flow.addCard();
    response = [_card('new')];
    await flow.refresh();
    expect(flow.addState, CardAddState.cancelled);
    expect(flow.newCardId, isNull);
  });

  test('unsuccessful launch is retryable without creating a second hosted link',
      () async {
    var links = 0;
    var opened = false;
    final flow = CardFlow(
      readCards: () async => [_card('old')],
      generateLink: () async {
        links++;
        return _link;
      },
      openForm: (_, __) async =>
          opened ? CardFormOutcome.opened : CardFormOutcome.failed,
    );
    addTearDown(flow.dispose);
    await flow.refresh();
    await flow.addCard();
    expect(flow.addState, CardAddState.launchFailed);
    expect(flow.messageIsError, isTrue);
    expect(flow.newCardId, isNull);
    opened = true;
    await flow.addCard();
    expect(links, 1);
    expect(flow.addState, CardAddState.awaiting);
    expect(flow.messageIsError, isFalse);
  });

  test(
      'a blocked second popup replaces earlier success with a retryable failure',
      () async {
    var blocked = false;
    var links = 0;
    Object? response = [_card('old')];
    final flow = CardFlow(
      readCards: () async => response,
      requiresWindow: true,
      reserveWindow: () => blocked ? null : Object(),
      generateLink: () async {
        links++;
        return _link;
      },
      openForm: (_, __) async => CardFormOutcome.opened,
    );
    addTearDown(flow.dispose);
    await flow.refresh();
    await flow.addCard();
    response = [_card('new')];
    await flow.refresh();
    expect(flow.addState, CardAddState.confirmed);
    blocked = true;
    await flow.addCard();
    expect(flow.addState, CardAddState.idle);
    expect(flow.messageIsError, isTrue);
    expect(flow.newCardId, isNull);
    expect(flow.canAdd, isTrue);
    expect(links, 1);
  });

  test('non-hosted URLs never open a provider and a new link can be retried',
      () async {
    for (final link in [
      'javascript:alert(1)',
      'file:///card',
      '/card',
      'https://',
      'https://user:password@fixture-bank.example/card'
    ]) {
      var launched = false;
      final flow = CardFlow(
        readCards: () async => <Object>[],
        generateLink: () async => AddCardLinkResult(
            success: true, link: link, message: 'Provider link'),
        openForm: (_, __) async {
          launched = true;
          return CardFormOutcome.opened;
        },
      );
      await flow.refresh();
      await flow.addCard();
      expect(launched, isFalse);
      expect(flow.messageIsError, isTrue);
      expect(flow.canAdd, isTrue);
      flow.dispose();
    }
  });

  testWidgets(
      'stalled link releases popup and retry ignores its late completion',
      (tester) async {
    final stalled = Completer<AddCardLinkResult>();
    var links = 0;
    var launches = 0;
    var closed = 0;
    final flow = CardFlow(
      requestTimeout: const Duration(seconds: 5),
      readCards: () async => [_card('old')],
      reserveWindow: () => Object(),
      closeWindow: (_) => closed++,
      generateLink: () => ++links == 1 ? stalled.future : Future.value(_link),
      openForm: (_, __) async {
        launches++;
        return CardFormOutcome.opened;
      },
    );
    addTearDown(flow.dispose);
    await flow.refresh();
    final first = flow.addCard();
    await flow.addCard();
    expect(links, 1);
    await tester.pump(const Duration(seconds: 6));
    await first;
    expect(flow.preparing, isFalse);
    expect(flow.messageIsError, isTrue);
    expect(flow.canAdd, isTrue);
    expect(closed, 1);
    await flow.addCard();
    expect(launches, 1);
    expect(flow.awaiting, isTrue);
    stalled.complete(_link);
    await tester.pump();
    expect(launches, 1);
    expect(flow.awaiting, isTrue);
    expect(flow.newCardId, isNull);
  });

  test('binding after a failed read never confirms an existing card', () async {
    Object? response = [_card('existing')];
    final flow = CardFlow(
      readCards: () async => response,
      generateLink: () async => _link,
      openForm: (_, __) async => CardFormOutcome.opened,
    );
    addTearDown(flow.dispose);
    await flow.refresh();
    response = null;
    await flow.refresh();
    expect(flow.canAdd, isTrue);
    await flow.addCard();
    response = [_card('existing')];
    await flow.refresh();
    expect(flow.awaiting, isTrue);
    expect(flow.newCardId, isNull);
    flow.cancel();
    await flow.refresh();
    await flow.addCard();
    response = [_card('existing'), _card('new')];
    await flow.refresh();
    expect(flow.addState, CardAddState.confirmed);
    expect(flow.newCardId, 'new');
  });

  test('partial baseline cannot confirm a formerly rejected identity',
      () async {
    Object? response = [
      _card('valid'),
      {'id': 'existing', 'mask': null},
    ];
    final flow = CardFlow(
      readCards: () async => response,
      generateLink: () async => _link,
      openForm: (_, __) async => CardFormOutcome.opened,
    );
    addTearDown(flow.dispose);
    await flow.refresh();
    await flow.addCard();
    response = [_card('valid'), _card('existing')];
    await flow.refresh();
    expect(flow.partialWarning, isNull);
    expect(flow.awaiting, isTrue);
    expect(flow.newCardId, isNull);
  });

  test('authentication loss clears stale identities and binding baseline',
      () async {
    var authenticated = true;
    final flow = CardFlow(
      readCards: () async {
        if (!authenticated) {
          throw const SavedCardReadException(
              SavedCardReadFailure.authentication);
        }
        return [_card('existing')];
      },
      generateLink: () async => _link,
      openForm: (_, __) async => CardFormOutcome.opened,
    );
    addTearDown(flow.dispose);
    await flow.refresh();
    await flow.addCard();
    authenticated = false;
    await flow.refresh();
    expect(flow.authRequired, isTrue);
    expect(flow.cards, isEmpty);
    expect(flow.canAdd, isFalse);
    expect(flow.awaiting, isTrue);
    authenticated = true;
    await flow.refresh();
    expect(flow.authRequired, isFalse);
    expect(flow.awaiting, isTrue);
    expect(flow.newCardId, isNull);
  });

  test('authentication refused during link preparation blocks further launch',
      () async {
    var launches = 0;
    final flow = CardFlow(
      readCards: () async => [_card('existing')],
      generateLink: () async => const AddCardLinkResult(
        success: false,
        authRequired: true,
        message: 'Session expired',
      ),
      openForm: (_, __) async {
        launches++;
        return CardFormOutcome.opened;
      },
    );
    addTearDown(flow.dispose);
    await flow.refresh();
    await flow.addCard();
    expect(flow.authRequired, isTrue);
    expect(flow.cards, isEmpty);
    expect(flow.canAdd, isFalse);
    expect(flow.preparing, isFalse);
    await flow.addCard();
    expect(launches, 0);
    await flow.refresh();
    expect(flow.authRequired, isFalse);
    expect(flow.canAdd, isTrue);
  });

  test(
      'cancelling during refresh cannot turn its late new identity into success',
      () async {
    final returningCards = Completer<Object?>();
    var reads = 0;
    final flow = CardFlow(
      readCards: () =>
          ++reads == 1 ? Future.value([_card('old')]) : returningCards.future,
      generateLink: () async => _link,
      openForm: (_, __) async => CardFormOutcome.opened,
    );
    addTearDown(flow.dispose);
    await flow.refresh();
    await flow.addCard();
    final refreshing = flow.refresh();
    flow.cancel();
    returningCards.complete([_card('old'), _card('new')]);
    await refreshing;
    expect(flow.cards.map((card) => card.chargeId), ['old', 'new']);
    expect(flow.addState, CardAddState.cancelled);
    expect(flow.newCardId, isNull);
    expect(flow.canAdd, isTrue);
  });
}
