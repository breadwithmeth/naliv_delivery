import 'item_name_prefix_rules.dart';
import 'item_name_packaging_rules.dart';

class ItemTitlePresentation {
  final String name;
  final String? type;
  final String? packagingType;

  const ItemTitlePresentation({
    required this.name,
    this.type,
    this.packagingType,
  });

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
      break;
    }
  }

  cleaned = _trimSeparators(_normalizeSpaces(cleaned));
  if (cleaned.isEmpty) {
    cleaned = original;
  }

  final type = fallbackType ?? _cleanType(removedChunks.join(' '));
  return ItemTitlePresentation(
    name: cleaned,
    type: type,
    packagingType: packagingType,
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

  // Prefer longer prefixes first so specific matches win over generic ones.
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

  // Keep short but meaningful names (e.g. IPA, 7UP) while avoiding punctuation-only remnants.
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
