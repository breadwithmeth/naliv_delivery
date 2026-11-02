---
name: flutter-implement-json-serialization
description: Use when adding or changing JSON model decoding, encoding, numeric conversions, or missing/null field handling in Flutter.
---
# Manual Flutter JSON serialization

## Follow the model's contract

Read the existing model and its consumers before adding a mapping. This repository uses manual serialization: start with `lib/model/item.dart` (`Item.fromJson`/`toJson`) and the affected feature model, such as `lib/features/profile/profile_account.dart`. Do not introduce `json_serializable`, `freezed`, `built_value`, build_runner or a model-layer migration for a field change.

- Decode with `dart:convert`; validate the top-level object/array shape and nested values at the boundary. `jsonDecode` returns dynamic data, not compile-time-validated models.
- Preserve accepted aliases and conversions already covered by fixtures. `Item` has existing numeric/string helpers; reuse them rather than imposing a different cast policy across the model.
- If a contract accepts both integer and fractional JSON numbers, normalize with `(value as num).toDouble()`, not `as double` or truncating `toInt()`. Accept numeric strings only where the existing contract supports them.
- Missing, null, invalid, empty and zero may mean different things. Use `containsKey` when absence differs from explicit null; preserve that distinction in the model and serializer. Do not use a default empty/zero model to hide malformed required data.
- Add `toJson` only where encoding is needed. Preserve wire keys, units and omission rules, including nested objects/lists. Do not serialize local-only or sensitive state accidentally.

## Small decoding example

```dart
import 'dart:convert';

Map<String, dynamic> decodeObject(String body) {
  final value = jsonDecode(body);
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object');
  }
  return value;
}
```

Pass the result to the existing factory; its field-specific validation remains authoritative. Keep HTTP status, nullable/result and exception conventions in `lib/utils/api.dart` unchanged unless changing that endpoint is the task. JSON support is not a reason to blanket-require 200/201 or replace nullable APIs.

Small payloads parse synchronously. Profile before adding `compute`; native callbacks execute in a separate isolate, but web callbacks run on the current event loop. Use pure callbacks and sendable inputs/results; top-level/static helpers avoid capturing UI/client state.

## Contract tests

Extend `test/regression/server_payload_normalization_test.dart` or the affected model/endpoint tests. Cover valid shapes, established int/double/string representations, missing/null/empty/zero, malformed nested data and encoding/round-trip behavior where applicable. Use strict synthetic fixtures for network-dependent parsing; no production writes.

Run affected tests via `dart run tool/design_harness.dart check <existing-test-path>`.

Reference: [compute platform behavior](https://api.flutter.dev/flutter/foundation/compute.html).
