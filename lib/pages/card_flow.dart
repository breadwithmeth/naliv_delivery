import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/api.dart';

Uri? hostedCardUri(String? value) {
  final uri = value == null ? null : Uri.tryParse(value.trim());
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

@immutable
class SavedCard {
  const SavedCard({
    required this.rowKey,
    required this.mask,
    this.chargeId,
  });

  final String rowKey;
  final String mask;
  final String? chargeId;
  bool get canCharge => chargeId != null;
  static final _digits = RegExp(r'\d');
  static final _validMask = RegExp(r'^[\d*•xX\s-]+$');
  static final _masking = RegExp(r'[*•xX]');
  static final _panIdentity = RegExp(r'^(?:\d[\s-]?){12,19}$');

  static String? safeMask(Object? value) {
    if (value is! String) return null;
    final mask = value.trim();
    final digitCount = _digits.allMatches(mask).length;
    return _validMask.hasMatch(mask) && _masking.hasMatch(mask) &&
            digitCount >= 4 && digitCount <= 10
        ? mask
        : null;
  }

  static SavedCardCollection parse(Object? value) {
    if (value is! List) throw const FormatException('Missing card collection');
    final ids = <String>{};
    final duplicates = <String>{};
    final displayable = <SavedCard>[];
    for (var index = 0; index < value.length; index++) {
      final raw = value[index];
      if (raw is! Map) continue;
      final mask = safeMask(raw['card_mask'] ?? raw['mask']);
      if (mask == null) continue;
      // Only this bank collection supplies charge identities. A bad provider ID
      // must not fall back to a local row ID; safe masks can still be displayed.
      final rawId = raw['halyk_id'] ?? raw['card_id'] ?? raw['id'];
      final id = rawId is String || rawId is int ? rawId.toString().trim() : '';
      final chargeId = id.isEmpty ||
              id.toLowerCase() == 'null' ||
              _panIdentity.hasMatch(id) ||
              (rawId is int && rawId <= 0)
          ? null
          : id;
      if (chargeId != null && !ids.add(chargeId)) {
        duplicates.add(chargeId);
      }
      displayable.add(SavedCard(
        rowKey: chargeId ?? 'summary-$index',
        chargeId: chargeId,
        mask: mask,
      ));
    }
    // Ambiguous valid identities stay visible as summaries, never chargeable.
    // A malformed mask above does not invalidate a different, valid bank row.
    for (var index = 0; index < displayable.length; index++) {
      final card = displayable[index];
      if (duplicates.contains(card.chargeId)) {
        displayable[index] = SavedCard(
          rowKey: 'summary-duplicate-$index',
          mask: card.mask,
        );
      }
    }
    return SavedCardCollection(
      cards: List<SavedCard>.unmodifiable(displayable),
      rejectedCount: value.length - displayable.length,
    );
  }
}

@immutable
class SavedCardCollection {
  const SavedCardCollection({required this.cards, required this.rejectedCount});

  final List<SavedCard> cards;
  final int rejectedCount;
  bool get complete =>
      rejectedCount == 0 && cards.every((card) => card.canCharge);
}

enum CardAddState {
  idle,
  preparing,
  awaiting,
  launchFailed,
  confirmed,
  cancelled
}

enum CardFormOutcome { opened, returned, cancelled, failed }

class CardFlow extends ChangeNotifier {
  CardFlow({
    required this.readCards,
    required this.openForm,
    this.generateLink = ApiService.generateAddCardLinkResult,
    this.reserveWindow,
    this.closeWindow,
    this.requiresWindow = false,
    this.requestTimeout = const Duration(seconds: 12),
  });

  final Future<Object?> Function() readCards;
  final Future<AddCardLinkResult> Function() generateLink;
  final Future<CardFormOutcome> Function(Uri, Object?) openForm;
  final Object? Function()? reserveWindow;
  final void Function(Object?)? closeWindow;
  final bool requiresWindow;
  final Duration requestTimeout;

  List<SavedCard> cards = const [];
  bool loading = false;
  bool hasLoaded = false;
  String? error;
  bool authRequired = false;
  String? partialWarning;
  String? message;
  bool messageIsError = false;
  CardAddState addState = CardAddState.idle;
  String? newCardId;
  Set<String>? _previousIds;
  bool _baselineNeedsRefresh = false;
  Uri? _preparedUri;
  Object? _reservedWindow;
  bool _disposed = false;
  int _attempt = 0;
  int _readAttempt = 0;

  bool get preparing => addState == CardAddState.preparing;
  bool get awaiting => addState == CardAddState.awaiting;
  bool get canAdd =>
      (hasLoaded || error != null) &&
      !authRequired &&
      !loading &&
      !preparing &&
      !awaiting;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (_disposed || loading || preparing) return;
    final attempt = ++_readAttempt;
    loading = true;
    error = null;
    _emit();
    try {
      final collection =
          SavedCard.parse(await readCards().timeout(requestTimeout));
      if (_disposed || attempt != _readAttempt) return;
      cards = collection.cards;
      hasLoaded = true;
      authRequired = false;
      if (collection.complete) _baselineNeedsRefresh = false;
      partialWarning = collection.complete
          ? null
          : cards.isEmpty
              ? 'Не удалось проверить ни одну запись карты. Список не подтверждён: попробуйте обновить его.'
              : 'Часть записей карт не подтверждена для оплаты. Скрытые номера показаны, но оплатить можно только картами с проверенным банковским идентификатором. Обновите список.';
      final previous = _previousIds;
      if (awaiting) {
        SavedCard? added;
        if (previous != null && collection.complete) {
          for (final card in cards) {
            if (card.canCharge && !previous.contains(card.chargeId)) {
              added = card;
              break;
            }
          }
        }
        if (added != null) {
          newCardId = added.chargeId;
          addState = CardAddState.confirmed;
          _previousIds = null;
          _preparedUri = null;
          message = 'Новая карта сохранена и готова к оплате';
          messageIsError = false;
        } else {
          message = previous == null
              ? 'Не удалось проверить список до привязки, поэтому новая карта не подтверждена. Можно обновить список или отменить ожидание; доступные карты будут показаны без подтверждения новой привязки.'
              : 'Банк ещё не подтвердил новую карту. Завершите привязку в форме банка и обновите список.';
          messageIsError = false;
        }
      }
    } on SavedCardReadException catch (failure) {
      if (_disposed || attempt != _readAttempt) return;
      authRequired = failure.reason == SavedCardReadFailure.authentication;
      if (authRequired) {
        cards = const [];
        hasLoaded = false;
        partialWarning = null;
        _previousIds = null;
        newCardId = null;
      }
      error = switch (failure.reason) {
        SavedCardReadFailure.authentication =>
          'Войдите в аккаунт снова, чтобы загрузить сохранённые карты.',
        SavedCardReadFailure.invalidData =>
          'Сервис вернул некорректный список карт. Попробуйте обновить его.',
        SavedCardReadFailure.unavailable =>
          'Не удалось загрузить карты. Попробуйте снова.',
      };
    } on TimeoutException {
      if (_disposed || attempt != _readAttempt) return;
      error = 'Сервис карт не ответил вовремя. Попробуйте снова.';
    } on FormatException {
      if (_disposed || attempt != _readAttempt) return;
      error =
          'Сервис вернул некорректный список карт. Попробуйте обновить его.';
    } catch (_) {
      if (_disposed || attempt != _readAttempt) return;
      error = 'Не удалось загрузить карты. Попробуйте снова.';
    } finally {
      if (!_disposed && attempt == _readAttempt) {
        loading = false;
        _emit();
      }
    }
  }

  Future<void> addCard() async {
    if (_disposed || !canAdd) return;
    final attempt = ++_attempt;
    newCardId = null;
    // Reserve the popup before the first await, while the user's gesture is active.
    Object? window;
    try {
      window = reserveWindow?.call();
    } catch (_) {
      _fail(
          'Не удалось открыть вкладку банка. Разрешите всплывающие окна и попробуйте снова.',
          keepLink: _preparedUri != null);
      return;
    }
    if (requiresWindow && window == null) {
      _fail(
          'Браузер заблокировал форму банка. Разрешите всплывающие окна и попробуйте снова.',
          keepLink: _preparedUri != null);
      return;
    }
    _reservedWindow = window;
    final retryingLaunch =
        addState == CardAddState.launchFailed && _preparedUri != null;
    _previousIds = !_baselineNeedsRefresh &&
            error == null &&
            hasLoaded &&
            partialWarning == null
        ? cards.where((card) => card.canCharge)
            .map((card) => card.chargeId!).toSet()
        : null;
    addState = CardAddState.preparing;
    message = 'Открываем форму банка…';
    messageIsError = false;
    _emit();
    try {
      if (!retryingLaunch) {
        final result = await generateLink().timeout(requestTimeout);
        if (_disposed || attempt != _attempt) return;
        if (!result.success) {
          if (result.authRequired) {
            authRequired = true;
            cards = const [];
            hasLoaded = false;
            partialWarning = null;
            error =
                'Войдите в аккаунт снова, чтобы загрузить сохранённые карты.';
          }
          _fail(result.message, keepLink: false);
          return;
        }
        _preparedUri = hostedCardUri(result.link);
        if (_preparedUri == null) {
          _fail('Банк вернул некорректную ссылку. Попробуйте получить новую.',
              keepLink: false);
          return;
        }
      }
      final outcome = await openForm(_preparedUri!, window);
      if (_disposed || attempt != _attempt) return;
      switch (outcome) {
        case CardFormOutcome.failed:
          _fail('Не удалось открыть форму банка. Попробуйте снова.',
              keepLink: true);
        case CardFormOutcome.cancelled:
          cancel();
          await refresh();
        case CardFormOutcome.opened:
        case CardFormOutcome.returned:
          _reservedWindow = null;
          addState = CardAddState.awaiting;
          message =
              'Завершите привязку в форме банка, затем вернитесь и обновите список карт.';
          _emit();
          if (outcome == CardFormOutcome.returned) await refresh();
      }
    } on TimeoutException {
      if (!_disposed && attempt == _attempt) {
        _fail('Сервис привязки карты не ответил вовремя. Попробуйте снова.',
            keepLink: false);
      }
    } catch (_) {
      if (!_disposed && attempt == _attempt) {
        _fail('Не удалось открыть форму банка. Попробуйте снова.',
            keepLink: _preparedUri != null);
      }
    }
  }

  void _fail(String text, {required bool keepLink}) {
    closeWindow?.call(_reservedWindow);
    _reservedWindow = null;
    addState = keepLink ? CardAddState.launchFailed : CardAddState.idle;
    if (!keepLink) _preparedUri = null;
    _previousIds = null;
    message = text;
    messageIsError = true;
    _emit();
  }

  void cancel() {
    if (_disposed) return;
    ++_attempt;
    newCardId = null;
    closeWindow?.call(_reservedWindow);
    _reservedWindow = null;
    _previousIds = null;
    _baselineNeedsRefresh = true;
    _preparedUri = null;
    addState = CardAddState.cancelled;
    message =
        'Ожидание отменено. Если привязка завершится в банке, карта появится после обновления списка.';
    messageIsError = false;
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_attempt;
    ++_readAttempt;
    closeWindow?.call(_reservedWindow);
    super.dispose();
  }
}
