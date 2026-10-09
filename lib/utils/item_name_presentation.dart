import '../core/quantity.dart';
import '../model/item.dart';

import 'item_name_country_rules.dart';
import 'item_name_packaging_rules.dart';
import 'item_name_prefix_rules.dart';

class ItemTitlePresentation {
  final String name;
  final String? type;
  final String? packagingType;
  final String? countryName;
  final String? countryFlag;
  final double? volumeLiters;
  final double? alcoholPercent;
  final String? material;
  final double? weightKilograms;

  const ItemTitlePresentation({
    required this.name,
    this.type,
    this.packagingType,
    this.countryName,
    this.countryFlag,
    this.volumeLiters,
    this.alcoholPercent,
    this.material,
    this.weightKilograms,
  });

  String? get volumeLabel =>
      volumeLiters == null ? null : '${_formatMetricValue(volumeLiters!)} л';

  String? get weightLabel =>
      weightKilograms == null ? null : '${_formatMetricValue(weightKilograms!)} кг';

  String? get alcoholLabel =>
      alcoholPercent == null ? null : '${_formatMetricValue(alcoholPercent!)}%';

  List<String> get pricingAttributes {
    final result = <String>[];
    final volume = volumeLabel;
    final weight = weightLabel;
    final alcohol = alcoholLabel;

    if (volume != null) {
      result.add(volume);
    }
    if (weight != null) {
      result.add(weight);
    }
    if (alcohol != null) {
      result.add(alcohol);
    }

    return result;
  }

  List<String> get attributes {
    final result = <String>[];
    final normalizedType = _cleanType(type);
    final normalizedPackaging = _cleanType(packagingType);
    final normalizedMaterial = _cleanType(material);

    if (normalizedType != null) {
      result.add(normalizedType);
    }
    if (normalizedPackaging != null &&
        !result.any((item) =>
            item.toLowerCase() == normalizedPackaging.toLowerCase())) {
      result.add(normalizedPackaging);
    }
    if (normalizedMaterial != null &&
        !result.any((item) =>
            item.toLowerCase() == normalizedMaterial.toLowerCase())) {
      result.add(normalizedMaterial);
    }
    final normalizedCountry = _cleanType(countryName);
    if (normalizedCountry != null &&
        !result.any(
            (item) => item.toLowerCase() == normalizedCountry.toLowerCase())) {
      result.add(normalizedCountry);
    }
    for (final attribute in pricingAttributes) {
      if (!result
          .any((item) => item.toLowerCase() == attribute.toLowerCase())) {
        result.add(attribute);
      }
    }

    return result;
  }
}

ItemTitlePresentation presentItem(
  Item item, {
  String? storedType,
  String? storedPackagingType,
}) =>
    presentItemName(
      rawName: item.name,
      categoryName: item.category?.name,
      storedType: item.itemType ?? storedType,
      storedPackagingType: item.packagingType ?? storedPackagingType,
      storedMaterial: item.material,
      storedCountryName: item.countryName,
      storedVolumeLiters: item.volumeLiters,
      storedWeightKilograms: item.weightKilograms,
      storedAlcoholPercent: item.alcoholPercent,
      allowImplicitVolume: quantityUnitLabel(item.unit) != 'кг',
    );

ItemTitlePresentation presentOrderItem(Map<String, dynamic> orderItem) {
  Map<String, dynamic> snapshot = const {};
  for (final key in const ['item_data', 'item', 'catalog_item', 'product']) {
    final candidate = orderItem[key];
    if (candidate is Map) {
      snapshot = Map<String, dynamic>.from(candidate);
      break;
    }
  }
  final historical = <String, dynamic>{
    ...snapshot,
    for (final key in const [
      'item_type',
      'packaging_type',
      'material',
      'country_name',
      'volume_liters',
      'weight_kilograms',
      'alcohol_percent',
      'unit',
      'category',
    ])
      if (orderItem[key] != null) key: orderItem[key],
    'item_id': orderItem['item_id'] ?? snapshot['item_id'],
    'name': orderItem['name'] ??
        orderItem['item_name'] ??
        snapshot['name'] ??
        'Товар',
  };
  return presentItem(Item.fromJson(historical));
}

ItemTitlePresentation presentItemName({
  required String rawName,
  String? categoryName,
  String? storedType,
  String? storedPackagingType,
  String? storedMaterial,
  String? storedCountryName,
  double? storedVolumeLiters,
  double? storedWeightKilograms,
  double? storedAlcoholPercent,
  bool allowImplicitVolume = true,
}) {
  final original = _normalizeSpaces(rawName);
  final fallbackType = _cleanType(storedType) ?? _cleanType(categoryName);
  String? packagingType = _cleanType(storedPackagingType);
  String? countryName = _cleanType(storedCountryName);
  String? countryFlag =
      countryName == null ? null : _resolveCountry(countryName)?.flag;

  if (original.isEmpty) {
    return ItemTitlePresentation(
      name: rawName.trim(),
      type: fallbackType,
      packagingType: packagingType,
      material: _cleanType(storedMaterial),
      countryName: countryName,
      countryFlag: countryFlag,
      volumeLiters: storedVolumeLiters,
      weightKilograms: storedWeightKilograms,
      alcoholPercent: storedAlcoholPercent,
    );
  }

  var cleaned = original;
  final removedChunks = <String>[];
  final rules = _buildRules(categoryName);
  final packagingRules = _buildPackagingRules();

  while (true) {
    final before = cleaned;

    for (final rule in rules) {
      final stripped = _stripLeadingSafe(cleaned, rule);
      if (stripped != cleaned) {
        removedChunks.add(rule);
        cleaned = stripped;
        break;
      }
    }

    for (final rule in packagingRules) {
      final stripped = _stripLeadingSafe(cleaned, rule.prefix);
      if (stripped != cleaned) {
        packagingType ??= rule.label;
        cleaned = stripped;
        break;
      }
    }

    if (before == cleaned) {
      for (final rule in packagingRules) {
        final stripped = _stripPackagingTokenSafe(cleaned, rule.prefix);
        if (stripped != cleaned) {
          packagingType ??= rule.label;
          cleaned = stripped;
          break;
        }
      }
    }

    if (before == cleaned) {
      break;
    }
  }

  cleaned = _trimSeparators(_normalizeSpaces(cleaned));
  final extractedCountry = _extractCountry(cleaned);
  if (extractedCountry != null) {
    countryName ??= extractedCountry.label;
    if (countryName == extractedCountry.label) {
      countryFlag ??= extractedCountry.flag;
    }
    cleaned = extractedCountry.cleaned;
  }
  final extractedSpecs = _extractInlineSpecs(cleaned,
      allowImplicitVolume:
          allowImplicitVolume && storedWeightKilograms == null);
  cleaned = extractedSpecs.cleaned;
  if (cleaned.isEmpty) {
    cleaned = original;
  }

  final type = fallbackType ?? _cleanType(removedChunks.join(' '));
  return ItemTitlePresentation(
    name: cleaned,
    type: type,
    packagingType: packagingType,
    countryName: countryName,
    countryFlag: countryFlag,
    material: _cleanType(storedMaterial),
    volumeLiters: storedVolumeLiters ?? extractedSpecs.volumeLiters,
    weightKilograms: storedWeightKilograms ?? extractedSpecs.weightKilograms,
    alcoholPercent: storedAlcoholPercent ?? extractedSpecs.alcoholPercent,
  );
}

String _stripLeading(String text, String prefix) {
  final pattern = RegExp(
    '^${RegExp.escape(prefix)}(?=\$|[\\s\\-\\.,:|/]+)(?:[\\s\\-\\.,:|/]+)?',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(text);
  if (match == null) {
    return text;
  }
  return text.substring(match.end).trimLeft();
}

String _stripLeadingSafe(String text, String prefix) {
  final stripped = _stripLeading(text, prefix);
  if (stripped == text) {
    return text;
  }

  final remainder = _trimSeparators(_normalizeSpaces(stripped));
  if (!_looksLikeValidRemainder(remainder)) {
    return text;
  }

  return remainder;
}

String _stripPackagingTokenSafe(String text, String token) {
  final stripped = _stripPackagingToken(text, token);
  if (stripped == text) {
    return text;
  }

  final remainder = _trimSeparators(_normalizeSpaces(stripped));
  if (!_looksLikeValidRemainder(remainder)) {
    return text;
  }

  return remainder;
}

String _stripPackagingToken(String text, String token) {
  final pattern = RegExp(
    '(^|[\\s\\-\\.,:|/()]+)${RegExp.escape(token)}(?=\$|[\\s\\-\\.,:|/()]+)',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(text);
  if (match == null) {
    return text;
  }

  return _removeMatch(text, match);
}

_CountryExtraction? _extractCountry(String text) {
  final pattern = RegExp(r'\(([^()]+)\)');
  for (final match in pattern.allMatches(text)) {
    final rawCountry = _normalizeSpaces(match.group(1) ?? '');
    if (rawCountry.isEmpty) {
      continue;
    }

    final resolved = _resolveCountry(rawCountry);
    if (resolved == null) {
      continue;
    }

    final cleaned =
        _trimSeparators(_normalizeSpaces(_removeMatch(text, match)));
    if (!_looksLikeValidRemainder(cleaned)) {
      continue;
    }

    return _CountryExtraction(
      cleaned: cleaned,
      label: resolved.label,
      flag: resolved.flag,
    );
  }

  return null;
}

_ResolvedCountry? _resolveCountry(String rawCountry) {
  final normalized = rawCountry.toLowerCase();
  for (final rule in kItemNameCountryRules) {
    for (final alias in rule.aliases) {
      if (normalized == alias.toLowerCase()) {
        return _ResolvedCountry(label: rule.label, flag: rule.flag);
      }
    }
  }
  return null;
}

_ExtractedSpecs _extractInlineSpecs(String text,
    {required bool allowImplicitVolume}) {
  var cleaned = text;
  double? volumeLiters;
  double? alcoholPercent;
  double? weightKilograms;

  while (true) {
    final before = cleaned;

    if (alcoholPercent == null) {
      final extraction = _extractAlcoholPercent(cleaned);
      if (extraction != null) {
        alcoholPercent = extraction.value;
        cleaned = extraction.cleaned;
      }
    }

    if (weightKilograms == null) {
      final weight = _extractWeight(cleaned);
      if (weight != null) {
        weightKilograms = weight.value;
        cleaned = weight.cleaned;
      }
    }

    if (volumeLiters == null) {
      final explicitVolume = _extractExplicitVolume(cleaned);
      if (explicitVolume != null) {
        volumeLiters = explicitVolume.value;
        cleaned = explicitVolume.cleaned;
      }
    }

    if (volumeLiters == null &&
        weightKilograms == null &&
        allowImplicitVolume) {
      final implicitVolume = _extractImplicitVolume(cleaned);
      if (implicitVolume != null) {
        volumeLiters = implicitVolume.value;
        cleaned = implicitVolume.cleaned;
      }
    }

    cleaned = _trimSeparators(_normalizeSpaces(cleaned));
    if (before == cleaned) {
      break;
    }
  }

  return _ExtractedSpecs(
    cleaned: cleaned,
    volumeLiters: volumeLiters,
    alcoholPercent: alcoholPercent,
    weightKilograms: weightKilograms,
  );
}

_MetricExtraction? _extractWeight(String text) {
  final pattern = RegExp(
    r'(^|[\s\-\.,:|/()]+)(\d+(?:[\.,]\d+)?)\s*(кг|kg|г|g)(?=$|[\s\-\.,:|/()]+)',
    caseSensitive: false,
  );
  for (final match in pattern.allMatches(text)) {
    final value = _parseMetric(match.group(2));
    if (value == null || !value.isFinite || value <= 0) continue;
    final cleaned = _removeMatch(text, match);
    if (!_looksLikeValidRemainder(cleaned)) continue;
    final unit = match.group(3)!.toLowerCase();
    return _MetricExtraction(
        cleaned: cleaned,
        value: const ['г', 'g'].contains(unit) ? value / 1000 : value);
  }
  return null;
}

_MetricExtraction? _extractAlcoholPercent(String text) {
  final pattern = RegExp(
    r'(^|[\s\-\.,:|/()]+)(\d{1,2}(?:[\.,]\d{1,2})?)\s*%',
    caseSensitive: false,
  );

  for (final match in pattern.allMatches(text)) {
    final value = _parseMetric(match.group(2));
    if (value == null || value < 0 || value > 99.9) {
      continue;
    }

    final cleaned = _removeMatch(text, match);
    if (!_looksLikeValidRemainder(cleaned)) {
      continue;
    }

    return _MetricExtraction(cleaned: cleaned, value: _normalizeMetric(value));
  }

  return null;
}

_MetricExtraction? _extractExplicitVolume(String text) {
  final pattern = RegExp(
    r'(^|[\s\-\.,:|/()]+)(\d{1,4}(?:[\.,]\d{1,3})?)\s*(л|l|литр|литра|литров|мл|ml|cl|сл)(?=$|[\s\-\.,:|/()]+)',
    caseSensitive: false,
  );

  for (final match in pattern.allMatches(text)) {
    final value = _parseMetric(match.group(2));
    final unit = match.group(3)?.toLowerCase();
    if (value == null || unit == null) {
      continue;
    }

    final liters = _normalizeExplicitVolume(value, unit);
    if (liters == null) {
      continue;
    }

    final cleaned = _removeMatch(text, match);
    if (!_looksLikeValidRemainder(cleaned)) {
      continue;
    }

    return _MetricExtraction(cleaned: cleaned, value: liters);
  }

  return null;
}

_MetricExtraction? _extractImplicitVolume(String text) {
  final pattern = RegExp(
    r'(^|[\s\-\.,:|/()]+)(\d{1,2}(?:[\.,]\d{1,3})?)(?=$|[\s\-\.,:|/()]+)',
    caseSensitive: false,
  );

  for (final match in pattern.allMatches(text)) {
    final rawValue = match.group(2);
    final value = _parseMetric(rawValue);
    if (value == null) {
      continue;
    }

    final liters = _normalizeImplicitVolume(
      value,
      allowShiftedFraction: rawValue != null &&
          (rawValue.contains('.') || rawValue.contains(',')),
    );
    if (liters == null) {
      continue;
    }

    final cleaned = _removeMatch(text, match);
    if (!_looksLikeValidRemainder(cleaned)) {
      continue;
    }

    return _MetricExtraction(cleaned: cleaned, value: liters);
  }

  return null;
}

double? _normalizeExplicitVolume(double value, String unit) {
  late final double liters;

  switch (unit) {
    case 'мл':
    case 'ml':
      liters = value / 1000;
      break;
    case 'cl':
    case 'сл':
      liters = value / 100;
      break;
    default:
      liters = value;
      break;
  }

  if (liters <= 0 || liters > 20) {
    return null;
  }

  return _normalizeMetric(liters);
}

double? _normalizeImplicitVolume(double value,
    {required bool allowShiftedFraction}) {
  if (value >= 0.05 && value <= 2.5) {
    return _normalizeMetric(value);
  }

  if (allowShiftedFraction && value > 2.5 && value <= 9.9) {
    final shifted = value / 10;
    if (shifted >= 0.2 && shifted <= 1.5) {
      return _normalizeMetric(shifted);
    }
  }

  return null;
}

double? _parseMetric(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }

  return double.tryParse(raw.replaceAll(',', '.'));
}

double _normalizeMetric(double value) {
  return double.parse(value.toStringAsFixed(3));
}

String _removeMatch(String text, RegExpMatch match) {
  final leading = text.substring(0, match.start).trimRight();
  final trailing = text.substring(match.end).trimLeft();
  return _normalizeSpaces(
      [leading, trailing].where((part) => part.isNotEmpty).join(' '));
}

List<String> _buildRules(String? categoryName) {
  final seen = <String>{};
  final rules = <String>[];

  void addRule(String? value) {
    final rule = _cleanType(value);
    if (rule == null) {
      return;
    }
    final key = rule.toLowerCase();
    if (seen.add(key)) {
      rules.add(rule);
    }
  }

  addRule(categoryName);
  for (final rule in kItemNamePrefixRules) {
    addRule(rule);
  }

  rules.sort((a, b) => b.length.compareTo(a.length));
  return rules;
}

List<_PackagingRule> _buildPackagingRules() {
  final rules = <_PackagingRule>[];
  final seen = <String>{};

  for (final entry in kItemNamePackagingRules.entries) {
    final prefix = _cleanType(entry.key);
    final label = _cleanType(entry.value);
    if (prefix == null || label == null) {
      continue;
    }
    final key = prefix.toLowerCase();
    if (seen.add(key)) {
      rules.add(_PackagingRule(prefix: prefix, label: label));
    }
  }

  rules.sort((a, b) => b.prefix.length.compareTo(a.prefix.length));
  return rules;
}

bool _looksLikeValidRemainder(String value) {
  if (value.isEmpty) {
    return false;
  }

  final tokenCount =
      value.split(RegExp(r'\s+')).where((token) => token.isNotEmpty).length;
  if (tokenCount == 0) {
    return false;
  }

  final hasLetterOrDigit = RegExp(r'[A-Za-zА-Яа-яЁё0-9]').hasMatch(value);
  if (!hasLetterOrDigit) {
    return false;
  }

  return true;
}

String _normalizeSpaces(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _trimSeparators(String value) {
  return value.replaceAll(RegExp(r'^[\s\-\.,:|/]+|[\s\-\.,:|/]+$'), '').trim();
}

String _formatMetricValue(double value) =>
    formatQuantity(value, '').replaceAll('.', ',');

String? _cleanType(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

class _PackagingRule {
  final String prefix;
  final String label;

  const _PackagingRule({
    required this.prefix,
    required this.label,
  });
}

class _ExtractedSpecs {
  final String cleaned;
  final double? volumeLiters;
  final double? alcoholPercent;
  final double? weightKilograms;

  const _ExtractedSpecs({
    required this.cleaned,
    required this.volumeLiters,
    required this.alcoholPercent,
    required this.weightKilograms,
  });
}

class _MetricExtraction {
  final String cleaned;
  final double value;

  const _MetricExtraction({
    required this.cleaned,
    required this.value,
  });
}

class _CountryExtraction {
  final String cleaned;
  final String label;
  final String flag;

  const _CountryExtraction({
    required this.cleaned,
    required this.label,
    required this.flag,
  });
}

class _ResolvedCountry {
  final String label;
  final String flag;

  const _ResolvedCountry({
    required this.label,
    required this.flag,
  });
}
