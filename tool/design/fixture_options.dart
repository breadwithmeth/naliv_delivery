import 'surface_manifest.dart';

class FixtureOptions {
  final String? surface;
  final String theme;
  final double textScale;
  final double keyboardInset;
  final String cards;
  final String payment;

  const FixtureOptions._(
      {required this.surface,
      required this.theme,
      required this.textScale,
      required this.keyboardInset,
      required this.cards,
      required this.payment});

  factory FixtureOptions.parse(
    Map<String, String> query, {
    required Iterable<String> cardScenarios,
    required Iterable<String> paymentScenarios,
  }) {
    const keys = {
      'surface',
      'theme',
      'scale',
      'keyboard',
      'guest',
      'cards',
      'payment'
    };
    final unknown = query.keys.where((key) => !keys.contains(key));
    if (unknown.isNotEmpty) {
      throw FormatException('Unknown fixture option: ${unknown.first}');
    }
    final surface = query['surface'];
    if (surface != null && !surfaceReferenceFrames.containsKey(surface)) {
      throw FormatException('Unknown fixture surface: $surface');
    }
    final theme = query['theme'] ?? 'dark';
    if (!{'dark', 'light'}.contains(theme)) {
      throw FormatException('Unknown fixture theme: $theme');
    }
    if (query['guest'] != null && !{'0', '1'}.contains(query['guest'])) {
      throw const FormatException('guest must be 0 or 1.');
    }
    final cards = query['cards'] ?? 'loaded';
    final payment = query['payment'] ?? 'completed';
    if (!cardScenarios.contains(cards)) {
      throw FormatException('Unknown card fixture: $cards');
    }
    if (!paymentScenarios.contains(payment)) {
      throw FormatException('Unknown payment fixture: $payment');
    }
    final scale = _number(query, 'scale', 1, positive: true);
    final keyboard = _number(query, 'keyboard', 0, positive: false);
    return FixtureOptions._(
        surface: surface,
        theme: theme,
        textScale: scale,
        keyboardInset: keyboard,
        cards: cards,
        payment: payment);
  }
}

double _number(Map<String, String> query, String key, double fallback,
    {required bool positive}) {
  if (!query.containsKey(key)) return fallback;
  final value = double.tryParse(query[key]!);
  if (value == null || !value.isFinite || (positive ? value <= 0 : value < 0)) {
    throw FormatException(
        '$key must be a finite ${positive ? 'positive' : 'nonnegative'} number.');
  }
  return value;
}
