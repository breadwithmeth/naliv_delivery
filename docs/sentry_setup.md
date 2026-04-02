# Sentry setup

The app has a production Sentry DSN configured in code and still allows overrides through Dart defines.

Required runtime values:

- none

Optional runtime values:

- `SENTRY_DSN`
- `SENTRY_ENVIRONMENT`
- `SENTRY_RELEASE`
- `SENTRY_DIST`
- `SENTRY_TRACES_SAMPLE_RATE`
- `SENTRY_PROFILES_SAMPLE_RATE`

Example:

```bash
flutter run \
  --dart-define=SENTRY_ENVIRONMENT=production \
  --dart-define=SENTRY_TRACES_SAMPLE_RATE=0.2
```

Defaults in code:

- environment comes from Flutter mode: `debug`, `profile`, or `release`
- release comes from `package_info_plus` as `packageName@version+buildNumber`
- dist comes from the platform build number

Privacy defaults in this integration:

- `sendDefaultPii=false`
- no screenshots
- no view hierarchy capture
- no user interaction tracing
- request and breadcrumb sanitization before sending