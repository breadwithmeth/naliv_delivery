---
name: flutter-use-http-package
description: Use when adding or changing REST requests, response handling, or HTTP transport tests in Flutter.
---
# Flutter HTTP requests

## Start with the existing contract

- Read `lib/utils/api.dart` (`ApiService`), the affected caller, and its tests. `http` is already declared in `pubspec.yaml`; do not add dependencies or replace the transport automatically.
- Keep existing authentication, endpoint-specific status codes, payloads and failure/result conventions. For example, auth send-code accepts 200 while verify-code accepts 202; HTTP method alone does not determine success. A successful HTTP status may still carry an API-level failure.
- Build query parameters with `Uri` APIs. Use `dart:convert` for JSON and string header names (`'Authorization'`, `'Content-Type'`); do not import `dart:io`/`HttpHeaders` into web-shared request code. Never log tokens or personal response bodies.
- Inspect platform permissions only when the affected target lacks them; do not rewrite manifests/entitlements as routine setup.

## Implement the smallest request

Reuse the existing top-level `http` calls, which tests intercept with `http.runWithClient`. If a method already receives a client, preserve injection and ownership; close only clients created by that scope. Do not introduce a cached client that bypasses fixture zones.

For a **new endpoint explicitly documented to return only 204**, a no-content operation can return `Future<void>`:

```dart
import 'package:http/http.dart' as http;

Future<void> deleteNoContent(http.Client client, Uri uri) async {
  final response = await client.delete(uri);
  if (response.statusCode != 204) {
    throw StateError('Delete failed: ${response.statusCode}');
  }
}
```

This illustrates response handling, not an app endpoint/auth contract. A 204 body must not be decoded and an empty model must not be fabricated. Preserve existing boolean/result APIs rather than changing callers incidentally.

Keep requests out of `build`; retain a Future in state or use the existing provider/controller. Represent loading, empty, error and success separately. Small payloads need no isolate. Profile expensive parsing first: `compute` uses a separate isolate on native platforms, but the current event loop on web. Use a pure callback and sendable inputs/results; top-level/static helpers avoid accidental closure capture.

## Safe proof

Extend `test/regression/api_contract_test.dart` or the affected endpoint test using strict `MockClient`/`http.runWithClient`. Assert method, URI, auth/body, endpoint-specific statuses, empty bodies, malformed JSON and failure propagation. Reject unexpected requests; never fall through to production. No real SMS, card/address mutations, orders or payments during verification.

Run the affected test through `dart run tool/design_harness.dart check <existing-test-path>`; integration checks are serial.

Reference: [compute platform behavior](https://api.flutter.dev/flutter/foundation/compute.html).
