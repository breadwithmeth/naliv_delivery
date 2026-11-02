import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/services/telemetry_consent_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryTransport implements Transport {
  final events = <SentryId?>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    events.add(envelope.header.eventId);
    return envelope.header.eventId;
  }
}

Future<void> _startReporting(_MemoryTransport transport) =>
    Sentry.init((options) {
      options.dsn = 'https://public@example.invalid/1';
      options.transport = transport;
      options.sendClientReports = false;
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Sentry.close();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    await Sentry.close();
    SharedPreferences.setMockInitialValues({});
  });

  test('a fresh install does not consent to telemetry', () async {
    expect(await TelemetryConsentService.loadConsent(), isFalse);
    expect(TelemetryConsentService.cachedConsent, isFalse);
  });

  test('reporting follows opt-in, revocation and a later opt-in', () async {
    await TelemetryConsentService.loadConsent();
    final transport = _MemoryTransport();
    await TelemetryConsentService.initialize(
      startReporting: () => _startReporting(transport),
    );
    expect(
      await Sentry.captureException(StateError('before consent')),
      const SentryId.empty(),
    );
    expect(transport.events, isEmpty);

    await TelemetryConsentService.setConsent(true);
    final allowed = await Sentry.captureException(
      StateError('consented error'),
    );
    expect(allowed, isNot(const SentryId.empty()));
    await TelemetryConsentService.setConsent(false);
    expect(
      await Sentry.captureException(StateError('private error')),
      const SentryId.empty(),
    );
    expect(transport.events, [allowed]);

    await TelemetryConsentService.setConsent(true);
    final resumed = await Sentry.captureException(
      StateError('consented again'),
    );
    expect(resumed, isNot(const SentryId.empty()));
    expect(transport.events, [allowed, resumed]);
  });

  test(
    'revocation waits for an initializing SDK and leaves it disabled',
    () async {
      SharedPreferences.setMockInitialValues({
        'telemetry_consent_enabled': true,
      });
      await TelemetryConsentService.loadConsent();
      final transport = _MemoryTransport();
      final started = Completer<void>();
      final finishStartup = Completer<void>();
      final initializing = TelemetryConsentService.initialize(
        startReporting: () async {
          await _startReporting(transport);
          started.complete();
          await finishStartup.future;
        },
      );
      await started.future;

      final revoked = TelemetryConsentService.setConsent(false);
      // Observe the persisted choice while startup remains blocked.
      expect(await TelemetryConsentService.loadConsent(), isFalse);
      finishStartup.complete();
      await Future.wait([initializing, revoked]);

      expect(Sentry.isEnabled, isFalse);
      expect(
        await Sentry.captureException(StateError('after concurrent revoke')),
        const SentryId.empty(),
      );
      expect(transport.events, isEmpty);
    },
  );
}
