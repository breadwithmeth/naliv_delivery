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

  const ItemTitlePresentation({
    required this.name,
    this.type,
    this.packagingType,
    this.countryName,
    this.countryFlag,
    this.volumeLiters,
    this.alcoholPercent,
  });

  String? get volumeLabel => volumeLiters == null ? null : '${_formatMetricValue(volumeLiters!)} л';

  String? get alcoholLabel => alcoholPercent == null ? null : '${_formatMetricValue(alcoholPercent!)}%';

  List<String> get pricingAttributes {
    final result = <String>[];
    final volume = volumeLabel;
    final alcohol = alcoholLabel;

    if (volume != null) {
      result.add(volume);
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

    if (normalizedType != null) {
      result.add(normalizedType);
    }
    if (normalizedPackaging != null && !result.any((item) => item.toLowerCase() == normalizedPackaging.toLowerCase())) {
      result.add(normalizedPackaging);
    }
    final normalizedCountry = _cleanType(countryName);
    if (normalizedCountry != null && !result.any((item) => item.toLowerCase() == normalizedCountry.toLowerCase())) {
      result.add(normalizedCountry);
    }
    for (final attribute in pricingAttributes) {
      if (!result.any((item) => item.toLowerCase() == attribute.toLowerCase())) {
        result.add(attribute);
      }
    }

    return result;
  }
}

ItemTitlePresentation presentItemName({
  required String rawName,
  String? categoryName,
  String? storedType,
  String? storedPackagingType,
}) {
  final original = _normalizeSpaces(rawName);
  final fallbackType = _cleanType(storedType) ?? _cleanType(categoryName);
  String? packagingType = _cleanType(storedPackagingType);
  String? countryName;
  String? countryFlag;

  if (original.isEmpty) {
    return ItemTitlePresentation(
      name: rawName.trim(),
      type: fallbackType,
      packagingType: packagingType,
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
    countryName = extractedCountry.label;
    countryFlag = extractedCountry.flag;
    cleaned = extractedCountry.cleaned;
  }
  final extractedSpecs = _extractInlineSpecs(cleaned);
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
    volumeLiters: extractedSpecs.volumeLiters,
    alcoholPercent: extractedSpecs.alcoholPercent,
  );
}

String _stripLeading(String text, String prefix) {
  final pattern = RegExp(
    '^${RegExp.escape(prefix)}(?:[\\s\\-\\.,:|/]+)?',
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

    final cleaned = _trimSeparators(_normalizeSpaces(_removeMatch(text, match)));
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

_ExtractedSpecs _extractInlineSpecs(String text) {
  var cleaned = text;
  double? volumeLiters;
  double? alcoholPercent;

  while (true) {
    final before = cleaned;

    if (alcoholPercent == null) {
      final extraction = _extractAlcoholPercent(cleaned);
      if (extraction != null) {
        alcoholPercent = extraction.value;
        cleaned = extraction.cleaned;
      }
    }

    if (volumeLiters == null) {
      final explicitVolume = _extractExplicitVolume(cleaned);
      if (explicitVolume != null) {
        volumeLiters = explicitVolume.value;
        cleaned = explicitVolume.cleaned;
      }
    }

    if (volumeLiters == null) {
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
  );
}

_MetricExtraction? _extractAlcoholPercent(String text) {
  final pattern = RegExp(
    r'(^|[\s\-\.,:|/()]+)(\d{1,2}(?:[\.,]\d{1,2})?)\s*%',
    caseSensitive: false,
  );

  for (final match in pattern.allMatches(text)) {
    final value = _parseMetric(match.group(2));
    if (value == null || value <= 0 || value > 99.9) {
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
    r'(^|[\s\-\.,:|/()]+)(\d{1,4}(?:[\.,]\d{1,2})?)\s*(л|l|литр|литра|литров|мл|ml|cl|сл)(?=$|[\s\-\.,:|/()]+)',
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
    r'(^|[\s\-\.,:|/()]+)(\d{1,2}(?:[\.,]\d{1,2})?)(?=$|[\s\-\.,:|/()]+)',
    caseSensitive: false,
  );

  for (final match in pattern.allMatches(text)) {
    final value = _parseMetric(match.group(2));
    if (value == null) {
      continue;
    }

    final liters = _normalizeImplicitVolume(value);
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

double? _normalizeImplicitVolume(double value) {
  if (value >= 0.05 && value <= 2.5) {
    return _normalizeMetric(value);
  }

  if (value > 2.5 && value <= 9.9) {
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
  return double.parse(value.toStringAsFixed(2));
}

String _removeMatch(String text, RegExpMatch match) {
  final leading = text.substring(0, match.start).trimRight();
  final trailing = text.substring(match.end).trimLeft();
  return _normalizeSpaces([leading, trailing].where((part) => part.isNotEmpty).join(' '));
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

  final tokenCount = value.split(RegExp(r'\s+')).where((token) => token.isNotEmpty).length;
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

String _formatMetricValue(double value) {
  final normalized = _normalizeMetric(value);
  if ((normalized - normalized.roundToDouble()).abs() < 0.001) {
    return normalized.toStringAsFixed(0);
  }
  if ((normalized * 10 - (normalized * 10).roundToDouble()).abs() < 0.001) {
    return normalized.toStringAsFixed(1).replaceAll('.', ',');
  }
  return normalized.toStringAsFixed(2).replaceAll('.', ',');
}

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

  const _ExtractedSpecs({
    required this.cleaned,
    required this.volumeLiters,
    required this.alcoholPercent,
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
