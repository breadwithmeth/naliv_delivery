import '../../utils/api.dart';

class ProfileAccount {
  const ProfileAccount({
    this.name,
    this.phone,
    this.addressSummary,
    this.cardsSummary,
  });

  final String? name;
  final String? phone;
  final String? addressSummary;
  final String? cardsSummary;

  factory ProfileAccount.fromJson(Map<String, dynamic> info) {
    final user = info['user'];
    if (user is! Map) {
      throw const FormatException('Account identity is missing');
    }
    final addresses = _records(info['addresses']);
    final cards = _records(info['cards']);
    final mask =
        cards == null || cards.isEmpty ? null : _text(cards.first['mask']);
    return ProfileAccount(
      name: _text(user['name']),
      phone: _text(user['login']),
      addressSummary: addresses == null
          ? null
          : addresses.isEmpty
              ? 'Нет сохранённых адресов'
              : '${_count(addresses.length, 'адрес', 'адреса', 'адресов')} · '
                  '${ApiService.formatAddressSummary(addresses.first as Map<String, dynamic>)}',
      cardsSummary: cards == null
          ? null
          : cards.isEmpty
              ? 'Добавленных карт нет'
              : '${_count(cards.length, 'карта', 'карты', 'карт')}'
                  '${mask == null ? '' : ' · $mask'}',
    );
  }

  static String? _text(Object? value) {
    final text = value is String ? value.trim() : null;
    return text == null || text.isEmpty ? null : text;
  }

  static List<dynamic>? _records(Object? value) {
    if (value == null) return null;
    if (value is! List) {
      throw const FormatException('Invalid account list');
    }
    for (final entry in value) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Invalid account record');
      }
    }
    return value;
  }

  static String _count(int count, String one, String few, String many) {
    final tail = count % 100;
    final word = tail >= 11 && tail <= 14
        ? many
        : switch (count % 10) {
            1 => one,
            2 || 3 || 4 => few,
            _ => many,
          };
    return '$count $word';
  }
}
