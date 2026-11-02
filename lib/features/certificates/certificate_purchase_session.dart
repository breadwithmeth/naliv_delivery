import 'package:flutter/foundation.dart';

import '../../core/json_payload.dart';
import '../../services/auth_service.dart';
import '../../utils/api.dart';
import '../../utils/financial_operation_journal.dart';

class CertificatePurchaseSession extends ChangeNotifier {
  CertificatePurchaseSession() {
    AuthService.sessionRevision.addListener(_credentialsChanged);
  }

  static final _whitespace = RegExp(r'\s');
  String amountText = '10000';
  String recipientLogin = '';
  String message = '';
  String? selectedCardId;
  String? purchaseId;
  String? error;
  Map<String, dynamic>? certificate;
  bool busy = false;
  bool _unconfirmed = false;
  bool _disposed = false;
  bool _blocked = false;
  bool _invalidated = false;
  int _credentialRevision = AuthService.credentialRevision;
  String? _account = AuthService.currentIdentity;
  Future<void>? _restoring;
  FinancialOperationJournal? _journal;

  bool get invalidated => _invalidated;
  bool get unconfirmed => _unconfirmed;
  bool get completed => certificate != null;
  bool get canPurchase =>
      !busy && !_blocked && !_invalidated && !_unconfirmed && !completed;

  static double? parseAmount(String text) {
    final amount = double.tryParse(
        text.trim().replaceAll(_whitespace, '').replaceAll(',', '.'));
    return amount != null && amount.isFinite && amount > 0 ? amount : null;
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _credentialsChanged() {
    final revision = AuthService.credentialRevision;
    if (_credentialRevision == revision) {
      if (_invalidated &&
          _account != null &&
          AuthService.currentIdentity == _account &&
          !busy) {
        restore();
      }
      return;
    }
    _credentialRevision = revision;
    _invalidated = true;
    certificate = null;
    purchaseId = null;
    error = 'Аккаунт изменился. Подтвердите аккаунт перед покупкой.';
    _emit();
  }

  Future<AuthSession?> _restore() async {
    final session = await AuthService.captureSession();
    if (session == null) {
      _blocked = true;
      error = 'Войдите в аккаунт перед покупкой сертификата';
      return null;
    }
    final account =
        AuthService.currentIdentity ?? await AuthService.refreshIdentity();
    if (!session.isCurrent || account == null || account.isEmpty) {
      _blocked = true;
      error = 'Не удалось подтвердить владельца покупки. Повторите вход.';
      return null;
    }
    final changedAccount = _account != null && _account != account;
    if (changedAccount) {
      amountText = '10000';
      recipientLogin = '';
      message = '';
      selectedCardId = null;
      certificate = null;
      purchaseId = null;
      _unconfirmed = false;
    }
    final journal = FinancialOperationJournal(
        account, FinancialOperationKind.certificatePurchase);
    final stored = await journal.read();
    if (!session.isCurrent || _disposed) return null;
    _account = account;
    _journal = journal;
    _blocked = stored.storageUnavailable;
    _invalidated = false;
    purchaseId = stored.intent?.identity;
    if (stored.intent != null) _unconfirmed = !stored.intent!.completed;
    if (_blocked) {
      error =
          'Не удалось прочитать сохранённую покупку. Новая оплата заблокирована.';
      return null;
    }
    error = null;
    final intent = stored.intent;
    if (intent != null) {
      final draft = intent.request;
      amountText = draft['amountText']?.toString() ?? amountText;
      recipientLogin = draft['recipientLogin']?.toString() ?? '';
      message = draft['message']?.toString() ?? '';
      selectedCardId = draft['selectedCardId']?.toString();
      purchaseId = intent.identity;
      _unconfirmed = !intent.completed;
      final rawCertificate = intent.result?['certificate'];
      certificate = intent.completed && rawCertificate is Map
          ? Map<String, dynamic>.from(rawCertificate)
          : null;
    } else {
      _unconfirmed = false;
      purchaseId = null;
    }
    return session;
  }

  Future<void> restore() =>
      _restoring ??= _restoreVisible().whenComplete(() => _restoring = null);

  Future<void> _restoreVisible() async {
    if (busy || _disposed) return;
    busy = true;
    _emit();
    try {
      await _restore();
    } catch (_) {
      _blocked = true;
      error =
          'Не удалось прочитать сохранённую покупку. Новая оплата заблокирована.';
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> purchase() async {
    final restoring = _restoring;
    if (restoring != null) await restoring;
    if (busy || completed || (_unconfirmed && !_invalidated)) return;
    busy = true;
    error = null;
    _emit();
    FinancialOperationJournal? journal;
    var reserved = false;
    var sent = false;
    try {
      final session = await _restore();
      if (session == null || _unconfirmed || completed || _disposed) return;
      final amount = parseAmount(amountText);
      if (amount == null) {
        error = 'Введите положительную сумму сертификата';
        return;
      }
      final cardId = selectedCardId;
      if (cardId == null || cardId.isEmpty) {
        error = 'Выберите сохранённую карту';
        return;
      }
      journal = _journal!;
      reserved = await journal.reserve({
        'amountText': amountText,
        'amount': amount,
        'recipientLogin': recipientLogin,
        'message': message,
        'selectedCardId': cardId,
      });
      if (!reserved) {
        await _restore();
        _blocked = true;
        error =
            'Не удалось сохранить покупку или предыдущая покупка не разрешена. Новая оплата не отправлена.';
        return;
      }
      if (!session.isCurrent || _disposed) {
        await journal.acknowledge(requestNotSent: true);
        return;
      }
      sent = true;
      final response = await ApiService.purchaseCertificate(
        amount: amount,
        paymentType: 'card',
        halykCardId: cardId,
        recipientLogin: recipientLogin.trim(),
        message: message.trim(),
        credentialToken: session.token,
      );
      await _settle(journal, response, purchasing: true);
      if (!_disposed && session.isCurrent) {
        await _restore();
        if (!_unconfirmed && !completed) {
          error = _message(response, 'Не удалось купить сертификат');
        }
      }
    } catch (_) {
      if (sent) {
        await journal?.settle(outcome: FinancialOperationOutcome.unknown);
      }
      if (!_disposed && !_invalidated) {
        _unconfirmed = sent;
        _blocked = !sent;
        error = sent
            ? 'Ответ об оплате не получен. Не повторяйте покупку: проверьте сертификаты или обратитесь в поддержку.'
            : 'Покупка не отправлена: не удалось сохранить её состояние.';
      }
    } finally {
      if (reserved) journal?.release();
      busy = false;
      _emit();
    }
  }

  Future<void> refreshStatus() async {
    final restoring = _restoring;
    if (restoring != null) await restoring;
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _emit();
    try {
      final session = await _restore();
      final id = purchaseId;
      final journal = _journal;
      if (session == null || !_unconfirmed || id == null || journal == null) {
        return;
      }
      final response = await ApiService.getCertificatePurchaseStatus(id,
          credentialToken: session.token);
      await _settle(journal, response, purchasing: false);
      if (!_disposed && session.isCurrent) {
        await _restore();
        if (_unconfirmed && response['success'] != true) {
          error = _message(response, 'Не удалось проверить оплату');
        }
      }
    } catch (_) {
      if (!_disposed && !_invalidated) {
        error = 'Не удалось проверить оплату. Покупка не будет повторена.';
      }
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> _settle(
      FinancialOperationJournal journal, Map<String, dynamic> response,
      {required bool purchasing}) async {
    final data = payloadMap(response['data']);
    final rawId = data['purchase_id'];
    final id = rawId is String || rawId is num ? rawId.toString().trim() : '';
    final rawCertificate = data['certificate'];
    final code = rawCertificate is Map ? rawCertificate['code'] : null;
    final completed = response['success'] == true &&
        data['payment_status'] == 'completed' &&
        code is String &&
        code.trim().isNotEmpty &&
        code.trim().toLowerCase() != 'null';
    final outcome = financialOperationOutcome(response, accepted: completed);
    // A failed read is not proof that a previously submitted purchase was refused.
    await journal.settle(
      outcome: (!purchasing || (id.isNotEmpty && id.toLowerCase() != 'null')) &&
              outcome == FinancialOperationOutcome.refused
          ? FinancialOperationOutcome.unknown
          : outcome,
      identity: id.isNotEmpty && id.toLowerCase() != 'null' ? id : null,
      result: data,
      completed: completed && outcome == FinancialOperationOutcome.accepted,
    );
  }

  Future<bool> acknowledgeCompleted() async {
    if (!completed || _journal == null) return false;
    return _journal!.acknowledge();
  }

  static String _message(Map<String, dynamic> response, String fallback) {
    final raw = response['error'] ?? response['message'];
    final message = raw is Map ? raw['message'] : raw;
    return message is String && message.trim().isNotEmpty ? message : fallback;
  }

  @override
  void dispose() {
    _disposed = true;
    AuthService.sessionRevision.removeListener(_credentialsChanged);
    super.dispose();
  }
}
