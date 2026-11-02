# Push notifications: OneSignal and Android FCM

The application uses **OneSignal**, not a direct FlutterFire Messaging client. Firebase Hosting is a separate deployment concern. Android delivery still uses FCM underneath OneSignal; configure its provider credentials in the OneSignal dashboard, never in the Flutter/browser bundle.

## Current integration

- Native initialization and subscription/account synchronization: `lib/services/notification_service.dart`.
- Android application ID: `kz.gradusy24.app`.
- Web initialization: `web/index.html`, `lib/services/onesignal_web_bridge_web.dart` and the existing `/onesignal/` workers.
- Notification preferences: `lib/pages/notification_settings_page.dart`.
- Notification taps use OneSignal `additionalData` and the existing destination/authentication flow. Native incoming URI routing is a separate, unresolved contract; verified domain association alone does not implement it.
- Current service identifiers are `subscriptionId`, `oneSignalId` and `pushToken`. The old `fcmToken`, topic subscription and client-side server-key tester examples did not describe the current implementation and have been removed.

## Android provider prerequisites

1. Confirm the existing OneSignal application selected by `_mobileOneSignalAppId` in the service.
2. In OneSignal, configure the Android Firebase/FCM v1 provider for the actual Firebase project backing this application. Service-account credentials belong only in the provider/dashboard or trusted server.
3. Keep the existing Android application ID and release-signing continuity. Do not register a replacement package just to match an old JSON file.
4. On an authorized signed test device, grant notification permission when requested, verify subscription/account binding, then check foreground, background and cold-start notification taps through the existing publisher.

`android/app/google-services.json` is stale registration material for a different package. The Google Services Gradle plugin is not applied and this JSON is not an active input to the inspected build. OneSignal includes native Firebase components transitively; that does not make the stale local JSON authoritative. Preserve provider registrations until their owner approves retirement or replacement. Do not add a second messaging stack to make an unused file appear necessary.

## Web and Apple

- Web deployment and worker/cache requirements: [Coolify/static hosting](coolify_static_site.md).
- Existing Apple identities, APNs and extension acceptance: [iOS push setup](ios_firebase_setup.md).
- Never put a Firebase server key, FCM service account or APNs private key in Dart, JavaScript, static hosting output, logs or screenshots.

Repository fixtures reject unknown requests and use synthetic notification data. They do not prove dashboard credentials, subscription delivery, APNs/FCM acceptance or signed-device notification behavior. Production/account verification remains read-only; do not send test pushes to a personal account without explicit authorization.

Provider reference: [OneSignal Android FCM credentials](https://documentation.onesignal.com/docs/android-firebase-credentials).
