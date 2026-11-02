# iOS push notifications: OneSignal and APNs

The current client uses OneSignal. Do not add `Firebase.configure()`, FlutterFire Messaging or a second token-registration implementation based on this document's former Firebase examples.

## Registered source identities

| Item | Existing value |
|---|---|
| Team | `W922PUY77B` |
| Runner bundle ID | `com.example.nalivDelivery` |
| Notification extension | `com.example.nalivDelivery.OneSignalNotificationServiceExtension` |
| Shared App Group | `group.com.example.nalivDelivery.onesignal` |
| Associated domain | `app.gradusy24.kz` |

These values agree across the Xcode project, app/extension entitlements, OneSignal overrides and checked-in AASA. Despite the historical `com.example` name, do not rename a registered app during configuration cleanup.

## Apple-account and build prerequisites

1. Confirm Push Notifications and the shared App Group for the existing app/extension IDs in the Apple Developer account. Provision both targets with their existing team.
2. Configure the corresponding APNs provider/key in the existing OneSignal application. Private `.p8` material belongs in the provider dashboard, not the repository or app bundle.
3. Build with **Xcode 26+** for the availability-gated native glass source. Runner and the notification extension currently deploy to iOS **15.2**; older supported systems use the Flutter shader path.
4. Before moving to the Xcode 27/iOS 27 SDK, complete and exercise Flutter's manual UIScene migration, preserving both generated plugin and `NativeLiquidGlassPlugin` registration. This custom AppDelegate is not eligible for the stock automatic migration. This is a next-SDK gate, not a reproduced Xcode 26 startup failure.
5. Run `flutter pub get` before the Apple build so `Flutter/Generated.xcconfig` supplies the shared app/extension marketing and build versions from `pubspec.yaml`. The extension uses that version input without importing Runner's Pods configuration.
6. Inspect the exported archive: extension frameworks belong in **Frameworks**, the `.appex` belongs in Runner's **PlugIns**, app/extension versions must agree, and signed entitlements/profiles must contain the intended App Group and APNs environment.

Do not change source `aps-environment=development` to `production` blindly. Automatic signing/provisioning determines the exported environment; inspect the signed archive and profile. The dormant `GoogleService-Info.plist` is not evidence of active Firebase initialization or a credential leak.

## Acceptance

Use an authorized signed device and the existing publisher to check permission, subscription/account binding, foreground/background delivery, cold-start taps and unlock behavior. Also exercise glass appearance, resizing/theme changes, taps and disposal. No Apple compilation, signing, APNs delivery or native-glass runtime acceptance is established by a Windows test run or fixture screenshot.

References: [Flutter UIScene migration](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate), [Apple APNs entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/aps-environment).
