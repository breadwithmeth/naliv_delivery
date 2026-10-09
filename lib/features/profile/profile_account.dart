import '../../utils/api.dart';
import '../../pages/card_flow.dart';

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
    final rawCards = info['cards'];
    if (rawCards != null && rawCards is! List) {
      throw const FormatException('Invalid account card list');
    }
    final cards = rawCards is List ? rawCards.whereType<Map>().toList() : null;
    final partialCards = rawCards is List && cards!.length != rawCards.length;
    String? mask;
    for (final card in cards ?? const <Map>[]) {
      mask ??= SavedCard.safeMask(card['card_mask'] ?? card['mask']);
    }
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
              ? partialCards
                  ? 'Не удалось прочитать данные карт'
                  : 'Добавленных карт нет'
              : '${_count(cards.length, 'карта', 'карты', 'карт')}'
                  '${mask == null ? '' : ' · $mask'}'
                  '${partialCards ? ' · Список неполный' : ''}',
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
