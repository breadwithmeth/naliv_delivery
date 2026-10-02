import 'package:flutter/foundation.dart';

import '../../utils/api.dart';

/// Retains a purchase draft and its server identity while payment is unresolved.
class CertificatePurchaseSession extends ChangeNotifier {
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

  bool get unconfirmed => _unconfirmed;
  bool get completed => certificate != null;
  bool get canPurchase => !busy && !_unconfirmed && !completed;

  static double? parseAmount(String text) {
    final amount = double.tryParse(
        text.trim().replaceAll(_whitespace, '').replaceAll(',', '.'));
    return amount != null && amount.isFinite && amount > 0 ? amount : null;
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> purchase() async {
    if (!canPurchase) return;
    final amount = parseAmount(amountText);
    if (amount == null) {
      error = 'Введите положительную сумму сертификата';
      _emit();
      return;
    }
    final cardId = selectedCardId;
    if (cardId == null || cardId.isEmpty) {
      error = 'Выберите сохранённую карту';
      _emit();
      return;
    }
    busy = true;
    error = null;
    _emit();
    try {
      final response = await ApiService.purchaseCertificate(
        amount: amount,
        paymentType: 'card',
        halykCardId: cardId,
        recipientLogin: recipientLogin.trim(),
        message: message.trim(),
      );
      if (_disposed) return;
      _accept(response, purchasing: true);
    } catch (_) {
      if (_disposed) return;
      _unconfirmed = true;
      error =
          'Ответ об оплате не получен. Не повторяйте покупку: проверьте список сертификатов или обратитесь в поддержку.';
    } finally {
      if (!_disposed) {
        busy = false;
        _emit();
      }
    }
  }

  Future<void> refreshStatus() async {
    final id = purchaseId;
    if (busy || !_unconfirmed || id == null) return;
    busy = true;
    error = null;
    _emit();
    try {
      final response = await ApiService.getCertificatePurchaseStatus(id);
      if (_disposed) return;
      _accept(response, purchasing: false);
    } catch (_) {
      if (_disposed) return;
      error = 'Не удалось проверить оплату. Покупка не будет повторена.';
    } finally {
      if (!_disposed) {
        busy = false;
        _emit();
      }
    }
  }

  void _accept(Map<String, dynamic> response, {required bool purchasing}) {
    final rawData = response['data'];
    final data = rawData is Map ? rawData : const <String, dynamic>{};
    final rawId = data['purchase_id'];
    final id = rawId is String || rawId is num ? rawId.toString().trim() : '';
    if (purchaseId == null && id.isNotEmpty && id.toLowerCase() != 'null') {
      purchaseId = id;
    }
    final rawCertificate = data['certificate'];
    final code = rawCertificate is Map ? rawCertificate['code'] : null;
    if (response['success'] == true &&
        data['payment_status'] == 'completed' &&
        code is String &&
        code.trim().isNotEmpty &&
        code.trim().toLowerCase() != 'null') {
      certificate = Map<String, dynamic>.from(rawCertificate as Map);
      _unconfirmed = false;
      error = null;
      return;
    }

    if (purchasing && response['success'] == false && purchaseId == null) {
      final statusCode = response['statusCode'];
      final transportUncertain =
          response['error'] == 'Ошибка сети или разбора ответа' ||
              (statusCode is int && statusCode >= 500);
      if (!transportUncertain) {
        error = _message(response, 'Не удалось купить сертификат');
        return;
      }
    }

    // An accepted, malformed or transport-uncertain response must never cause
    // another charge. Only a read of the retained purchase can resolve it.
    _unconfirmed = true;
    error = response['success'] == false
        ? _message(response, 'Не удалось проверить оплату')
        : null;
  }

  static String _message(Map<String, dynamic> response, String fallback) {
    final raw = response['error'] ?? response['message'];
    final message = raw is Map ? raw['message'] : raw;
    return message is String && message.trim().isNotEmpty ? message : fallback;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
