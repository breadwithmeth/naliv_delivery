# Release checklist

Use this before planning a version bump, preparing Android/iOS builds, publishing
store metadata, or pushing a web deployment to `main`. This is project-local;
[`.omp/AGENTS.md`](../.omp/AGENTS.md) requires assistants to read it as well.

## 1. Put the version decisions in the plan

Read the current files and state the previous value, intended value (including
unchanged), and reason for every applicable row. Do not infer store availability
from source code, a completed build, an upload, review approval, or a Git push.

| Decision | Authoritative source | Required action |
| --- | --- | --- |
| Release channel | User's requested web, Android, iOS, or combined release | Name the channels and the expected commit/artifacts. A web-only rebuild does not automatically require an app-version bump. |
| App marketing version and build number | `pubspec.yaml` → `version: X.Y.Z+N` | For a new mobile release, choose the intended marketing version and an acceptable new build number. Record the Flutter/Dart SDK used. |
| Android native versions | `android/app/build.gradle` reads `flutter.versionName` / `flutter.versionCode` | Do not add a second version constant. Inspect the actual signed APK/AAB metadata; consider existing Play tracks, installed version codes and split-per-ABI codes. Never uninstall just to bypass a downgrade. |
| iOS app and notification-extension versions | `ios/Runner/Info.plist` and `ios/Runner.xcodeproj/project.pbxproj` consume `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER` | Keep the Flutter-derived app/extension versions aligned. Do not bump unrelated RunnerTests versions or edit generated SDK settings. Verify the archive with the intended Xcode/Flutter toolchain. |
| Public Android release advertised to installed apps | `web/app-update.json` → `android` | Review every release; change only after that version is available to the whole intended Google Play audience. Record public-store evidence and the check time. Otherwise keep the prior value, or use `null` to disable. |
| Public iOS release advertised to installed apps | `web/app-update.json` → `ios` | Decide independently using App Store availability. Keep the old value during review or restricted rollout; an Android release does not advance iOS. |
| Generated web release identity and payload | `build/web/version.json`, copied `build/web/app-update.json`, and the rest of `build/web` | Regenerate with `dart run tool/design_harness.dart build --tracked`; never hand-edit generated version JSON or copy fixture output. |
| Hosting policy | `nginx.conf` / `Dockerfile`, or the active Coolify Static Nginx editor; `firebase.json` only for explicitly selected Firebase Hosting | Identify which configuration actually owns the public domain. A committed Nginx file does not configure Coolify's Static build pack automatically. |
| Human release evidence | `README.md`, `docs/redesign/STATUS.md`, and relevant release notes | Update current artifact/test/publication claims only after observing them. Keep historical numbers labelled historical; do not replace every version string in the repository. |

Keep package `kz.gradusy24.app`, iOS bundle `com.example.nalivDelivery`, signing
identities and existing store listing IDs unchanged. `pubspec.lock` and
`web/manifest.json` are not additional app-version counters. Do not commit local
SDK paths, generated native registrants, secrets, or incidental dependency
lockfile downgrades.

## 2. Build and verify the intended artifacts

- Run the narrow affected harness check first; for application changes follow
  the existing full/native integration policy in the README. Do not invent test
  results for documentation-only or host-only changes.
- Stop owned previews and keep Flutter processes serial. Inspect unexpected
  lockfile changes rather than silently publishing a dependency downgrade.
- Build signed mobile outputs only for the requested platforms. Verify their
  embedded versions, signatures and upgrade behavior; a fixture cannot prove a
  native store handoff or preserve a real installed account.
- Build production web with `build --tracked`, inspect the generated JSON, and
  smoke the tracked output with production writes blocked. Never publish
  `.figma_cache/harness/web`, which contains fixture-only synthetic data.
- Stage the intended artifacts and documentation only. Preserve unrelated local
  changes; integrate current remote `main` without force-pushing.

## 3. Publish mobile notices only after store availability

Publish/install a mobile binary containing `AppUpdateNotice` before expecting
future notices on that device. A Coolify web deployment cannot add this feature
to an already-installed older binary.

Once a store release is publicly available to its intended audience, update only
that platform's `web/app-update.json` value, rebuild the tracked web output, then
commit/push the changed metadata and resulting release artifacts. Keep values
unchanged for the other platform. For withdrawal, restore the prior advertised
version or set the affected platform to `null`.

Do not publish a fictitious higher version to test a dev phone. Use update
fixtures or an appropriately versioned feature-enabled development build instead.
The notice compares marketing versions, not build numbers; equal/newer installed
versions do not receive an offer, and the same advertised release may be snoozed
locally for 24 hours.

## 4. Verify the host after every deployment

First identify the active Coolify build strategy and configuration source using
[the hosting guide](coolify_static_site.md#active-coolify-nginx-configuration).
A Static-pack configuration change requires **Save + redeploy/image rebuild**;
restarting the old image is not enough. A Git push alone is not deployment proof.

Use cache-bypassed GETs against the actual public domain and record the results:

```sh
curl -i -H 'Cache-Control: no-cache' https://app.gradusy24.kz/app-update.json
curl -i -H 'Cache-Control: no-cache' https://app.gradusy24.kz/version.json
```

- `/app-update.json`: HTTP 200, JSON containing the independently approved Android
  and iOS values; `Cache-Control: no-cache, no-store, must-revalidate`,
  `Pragma: no-cache`, and `Expires: 0`.
- `/version.json`: HTTP 200, generated identity matching the intended web build;
  the same no-cache headers. Compare served bootstrap/bundle bytes with the
  intended artifact when versions are unchanged; version alone cannot identify
  an exact Git commit.
- `/index.html` and release entry/runtime files: no-cache policy from the
  checked-in server configuration. Refresh a real supported client-side route;
  it must reach the app shell, not a host 404.
- On the actual selected host, verify reserved missing association/worker paths
  return 404 rather than the app HTML. Verify a missing `/app-update.json` against
  an isolated server root; never remove the production file merely to test this.
- Missing headers, old JSON or a missing file mean host acceptance is not done.
  Inspect Coolify's source branch, deployment commit/build status, Base/Publish
  Directory, build strategy and active Nginx configuration. Repeated version
  bumps or rebuilds do not repair a wrong host configuration.

Report build, push, observed host publication and mobile-store acceptance as
separate results. State missing host/device access explicitly; never call an
unexercised deployment or native handoff verified.
