import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/generate_item_name_prefix_rules.dart <catalog.json> [output.dart] [minCount]',
    );
    exitCode = 64;
    return;
  }

  final inputPath = args[0];
  final outputPath = args.length > 1 ? args[1] : 'lib/utils/item_name_prefix_rules.dart';
  final minCount = args.length > 2 ? int.tryParse(args[2]) ?? 5 : 5;

  final inputFile = File(inputPath);
  if (!await inputFile.exists()) {
    stderr.writeln('Input file not found: $inputPath');
    exitCode = 66;
    return;
  }

  final raw = await inputFile.readAsString();
  final dynamic root = jsonDecode(raw);

  final itemNames = <String>[];
  final categoryNames = <String>[];
  _walk(root, itemNames, categoryNames);

  if (itemNames.isEmpty) {
    stderr.writeln('No item-like names found.');
    exitCode = 65;
    return;
  }

  final categoryVocabulary = _buildCategoryVocabulary(categoryNames);
  final prefixCounts = <String, int>{};

  for (final name in itemNames) {
    final tokens = _tokenize(name);
    if (tokens.isEmpty) continue;

    for (var size = 1; size <= 2; size++) {
      if (tokens.length < size) continue;
      final prefix = tokens.take(size).join(' ');
      if (_isLikelyCategoryPrefix(prefix, categoryVocabulary)) {
        prefixCounts[prefix] = (prefixCounts[prefix] ?? 0) + 1;
      }
    }
  }

  final selected = prefixCounts.entries.where((entry) => entry.value >= minCount).map((entry) => entry.key).toList()
    ..sort((a, b) {
      final byWords = b.split(' ').length.compareTo(a.split(' ').length);
      if (byWords != 0) return byWords;
      return a.compareTo(b);
    });

  final rendered = _renderDartFile(selected);
  await File(outputPath).writeAsString(rendered);

  stdout.writeln('Generated ${selected.length} prefix rules -> $outputPath');
}

void _walk(dynamic node, List<String> itemNames, List<String> categoryNames) {
  if (node is Map) {
    node.forEach((key, value) {
      final normalizedKey = key.toString().toLowerCase();
      if (value is String) {
        final cleaned = value.trim();
        if (cleaned.isEmpty) return;

        if (normalizedKey == 'name' || normalizedKey == 'item_name' || normalizedKey == 'title') {
          itemNames.add(cleaned);
        }
        if (normalizedKey.contains('category') && normalizedKey.contains('name')) {
          categoryNames.add(cleaned);
        }
      }
      _walk(value, itemNames, categoryNames);
    });
    return;
  }

  if (node is List) {
    for (final value in node) {
      _walk(value, itemNames, categoryNames);
    }
  }
}

Set<String> _buildCategoryVocabulary(List<String> categoryNames) {
  final result = <String>{};
  for (final category in categoryNames) {
    final tokens = _tokenize(category);
    if (tokens.isEmpty) continue;

    for (final token in tokens) {
      result.add(token);
    }

    for (var i = 0; i < tokens.length; i++) {
      for (var size = 1; size <= 2; size++) {
        if (i + size > tokens.length) continue;
        result.add(tokens.sublist(i, i + size).join(' '));
      }
    }
  }
  return result;
}

bool _isLikelyCategoryPrefix(String prefix, Set<String> categoryVocabulary) {
  if (categoryVocabulary.isEmpty) {
    return true;
  }

  if (categoryVocabulary.contains(prefix)) {
    return true;
  }

  final tokens = prefix.split(' ');
  return tokens.every(categoryVocabulary.contains);
}

List<String> _tokenize(String value) {
  final normalized = value.toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'[^a-zа-я0-9\s-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  if (normalized.isEmpty) {
    return const <String>[];
  }

  return normalized.split(' ').map((token) => token.trim()).where((token) => token.isNotEmpty).toList(growable: false);
}

String _renderDartFile(List<String> prefixes) {
  final buffer = StringBuffer();
  buffer.writeln('// GENERATED FILE.');
  buffer.writeln('// Update via:');
  buffer.writeln('// dart run tool/generate_item_name_prefix_rules.dart <catalog.json> [output.dart] [minCount]');
  buffer.writeln('');
  buffer.writeln('const List<String> kItemNamePrefixRules = <String>[');
  for (final prefix in prefixes) {
    buffer.writeln("  '${prefix.replaceAll("'", "\\'")}',");
  }
  buffer.writeln('];');
  return buffer.toString();
}
