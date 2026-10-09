import '../../core/money.dart';

/// A read-only balance and ledger snapshot returned by `/bonuses`.
class BonusAccount {
  const BonusAccount({required this.balance, required this.history});

  final num balance;
  final List<BonusLedgerEntry> history;

  factory BonusAccount.fromResponse(Map<String, dynamic>? response) {
    final data = response?['data'];
    if (response?['success'] != true || data is! Map) {
      throw const FormatException('Bonus account is unavailable');
    }
    final balance = _number(data['totalBonuses']);
    final history = data['bonusHistory'];
    if (balance == null || history is! List) {
      throw const FormatException('Bonus balance or ledger is unavailable');
    }
    return BonusAccount(
      balance: balance,
      history: List<BonusLedgerEntry>.unmodifiable([
        for (final entry in history)
          if (entry is Map)
            BonusLedgerEntry.fromJson(entry)
          else
            throw const FormatException('Invalid bonus ledger entry'),
      ]),
    );
  }

  Iterable<BonusLedgerEntry> entriesForOrder(String orderId) =>
      history.where((entry) => entry.orderId == orderId.trim());
}

/// A signed server operation, without inferring accrual or reversal from its sign.
class BonusLedgerEntry {
  const BonusLedgerEntry({
    required this.amount,
    this.id,
    this.orderId,
    this.returnId,
    this.reversalId,
    this.timestamp,
    this.description,
  });

  final num amount;
  final String? id;
  final String? orderId;
  final String? returnId;
  final String? reversalId;
  final String? timestamp;
  final String? description;

  factory BonusLedgerEntry.fromJson(Map<dynamic, dynamic> json) {
    final amount = _number(json['amount']);
    if (amount == null) {
      throw const FormatException('Bonus operation amount is unavailable');
    }
    return BonusLedgerEntry(
      amount: amount,
      id: _identity(json['bonusId']),
      orderId: _identity(json['orderId'] ?? json['order_id']),
      returnId: _identity(json['returnId'] ?? json['return_id']),
      reversalId: _identity(json['reversalId'] ?? json['reversal_id']),
      timestamp: _identity(json['timestamp']),
      description: _identity(json['description']),
    );
  }

  String get title => orderId != null
      ? 'Заказ №$orderId'
      : description ?? 'Операция с бонусами';

  String? get reference => returnId != null
      ? 'Возврат №$returnId'
      : reversalId != null
          ? 'Сторно №$reversalId'
          : id != null
              ? 'Проводка №$id'
              : null;
}

String bonusNumberLabel(num amount) {
  final money = formatTenge(amount.abs());
  return '${amount < 0 ? '−' : ''}${money.substring(0, money.length - 2)}';
}

String signedBonusLabel(num amount) =>
    '${amount > 0 ? '+' : amount < 0 ? '−' : ''}'
    '${bonusNumberLabel(amount.abs())} бонусов';

num? _number(Object? value) {
  final number = value is num ? value : num.tryParse('$value');
  return number != null && number.isFinite ? number : null;
}

String? _identity(Object? value) {
  if (value == null || (value is! String && value is! num)) return null;
  final text = value is num && value.isFinite && value % 1 == 0
      ? value.toInt().toString()
      : value.toString().trim();
  return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
}
