# Coolify and static web deployment

## Release output

The root-hosted release is `build/web`, intentionally retained as the deployment artifact. Build only after code and checks settle:

```sh
flutter build web --release --no-wasm-dry-run
```

For a Coolify static site, use `build/web` as the publish directory. The checked-in Dockerfile instead packages that prebuilt directory into nginx; it does not compile Flutter. Its Docker context is allowlisted to the web release, `nginx.conf` and the Docker control files. Signing keys, Figma credentials, SDK paths and application source are not build inputs.

Use the checked-in `nginx.conf`, rather than copying a second configuration from this document. It provides SPA fallback, uncached release entry/runtime metadata, strict missing-worker/association responses and JSON association endpoints. Missing paths under `/.well-known/`, `/onesignal/` and `/flutter_service_worker.js/` must not receive the app HTML. Keep the root Flutter worker endpoint during retirement of older installed workers; do not assume current Flutter generates the historical cache-first worker.

Static HTML, CSS, JavaScript, JSON, Wasm and SVG responses of at least 1 KiB can use
gzip when the client accepts it. `Vary: Accept-Encoding` separates compressed and
uncompressed responses; the release no-cache policy is unchanged. Already compressed
image/font formats are not added to the gzip type list.

The 1.2.115 release was served locally through Nginx 1.30.6 on Windows with only
the listen address and document root substituted. Four reserved missing paths changed
from app HTML/200 to 404; fourteen final HTTP cases passed. The actual main bundle
transferred 1,652,673 gzip bytes versus 4,882,480 uncompressed bytes (66.15% fewer
payload bytes), with identical decoded content. This is local Nginx/runtime proof,
not a Docker image build, production deployment or end-user latency measurement.

## Active Coolify Nginx configuration

The [Coolify Static build pack](https://coolify.io/docs/applications/builds/static)
uses its own generated Nginx configuration. A root `nginx.conf` in Git is not
automatically loaded by that build pack.

Before changing a server policy, inspect the application's actual **Build
strategy** and configuration:

- **Static:** open **General**, generate/open its Nginx configuration, and apply
  the applicable policy from [`nginx.conf`](../nginx.conf) inside the active
  server block. Preserve the actual document root/listen settings. A `root` inside
  `location /` is not inherited by sibling locations: explicitly repeat the same
  document root in each added exact location when the server has no root.
  For the mobile manifest, apply `location = /app-update.json` with its document
  root, three no-cache headers and strict missing-file 404. Save and
  **redeploy/build a new image**; restarting the existing image cannot apply a
  saved build-time configuration change.
- **Dockerfile:** the root build context and root `Dockerfile` must be selected.
  That Dockerfile copies `nginx.conf` into Nginx and packages prebuilt `build/web`;
  it does not compile Flutter or use the Static-pack configuration editor.

The operator-confirmed deployment uses **Static** with Publish Directory
**`/build/web`**. Its generated configuration defines
`root /usr/share/nginx/html;` inside `location /`, not at server level.
The exact `/app-update.json` location therefore needs its own
`root /usr/share/nginx/html;`. Omitting it caused the metadata URL to return the
custom 404 page while `/version.json` still returned the current build. A custom
`error_page` internal redirect can also change which location's headers apply.

Before the exact-location fix, `index.html` lacked the repository's configured
cache headers and a client-route probe returned 404 rather than SPA/200. These
are active-host policies, not Flutter build/version issues. Copying the
repository file without adapting root scope is insufficient. Without
administrative Coolify/SSH access, have the operator change the active editor and
redeploy, then verify the public response; do not claim a repository-only change
fixed it.

Use the release preflight and acceptance checks in
[`RELEASING.md`](RELEASING.md). Verify the live host rather than assuming a
successful Git push means that configuration has been deployed.


## Optional mobile update metadata

`web/app-update.json` is an owned static resource published as
`https://app.gradusy24.kz/app-update.json` by the normal `build --tracked` output.
Its contract is `{"android":"1.2.117","ios":"1.2.113"}`: independent **public store
marketing versions**, not Flutter/ABI build codes, `version.json` or `manifest.json`.
A missing/null platform value disables that platform's notice.

Advance a platform value manually **only after** that release is available to the
whole intended store audience. Keep the prior value during Play staged rollout or
Apple review; never advance it automatically on a source-version bump or web build.
For a withdrawn release, restore the prior value or set that platform to null.
Initial versions were rechecked on 2026-11-11 against
[Google Play's application metadata](https://play.google.com/store/apps/details?id=kz.gradusy24.app&hl=en&gl=KZ)
and [Apple's existing bundle lookup](https://itunes.apple.com/lookup?bundleId=com.example.nalivDelivery&country=kz).
Do not change the iOS bundle ID to the Android package.

Both hosting configurations reserve the exact metadata path, serve JSON with
`Cache-Control: no-cache, no-store, must-revalidate`, `Pragma: no-cache` and
`Expires: 0`, and exclude it from SPA fallback: a missing file must be HTTP 404.
Native HTTPS clients need no additional CORS policy. Build output is not deployment;
host publication and read-back require separate release authorization.

The notice is Android/iOS-only, optional and fail-open after at most five seconds.
Later, barrier/back dismissal and successful store opening snooze that release for
24 hours; another release has its own deadline. Failed persistence retains the
session cooldown only. Store opening does not prove installation. A first mobile
release containing this code must be published and installed before future notices
can work; existing featureless binaries cannot acquire it remotely.

Local Firebase Hosting emulator 15.13.0 on Windows served the built metadata as
JSON/200 and kept a missing metadata file at 404, while ordinary routes retained
SPA/200. **Header verification did not pass:** its `glob-slasher` dependency turns
`/app-update.json` into `\app-update.json`, which its glob matcher rejects, so
even existing `/version.json` cache headers were absent. Keep the
[documented Hosting header syntax](https://firebase.google.com/docs/hosting/full-config#headers);
re-exercise headers on a working Firebase host/emulator. nginx's `always` policy
also remains unexercised here because no nginx binary/container was available.


## Fixture isolation and publication

`dart run tool/design_harness.dart build` publishes fixture-only output under
`.figma_cache/harness/web`; `build --tracked` builds production `build/web`.
Never deploy the fixture directory or use its synthetic account as production proof.
The harness acquires its exclusive lock before changing validity markers or output.
`serve` holds that lock until shutdown, preventing a rebuild of actively served
fixtures. Failed/interrupted builds cannot be served as valid fixture output.

Fixture composition installs an in-memory push provider, and fixture HTML removes
the production OneSignal SDK loader. Tracked production HTML retains the loader.
The web bridge releases rejected initialization attempts for explicit retry while
sharing successful startup/listener ownership. Host fake-provider checks do not
establish real notification delivery.

## Push is OneSignal, not direct browser FCM

- Web push initializes OneSignal in `web/index.html` and uses the existing `/onesignal/` service workers.
- Serve those workers as JavaScript over valid HTTPS with their real paths and no-cache policy; missing workers must be HTTP 404, not `index.html`.
- Confirm the OneSignal application/origin configuration for the actual public hostname. Its current worker scope and paths assume a root deployment; `--base-href` alone does not establish subpath support.
- `FIREBASE_WEB_VAPID_KEY` is not consumed by the current client. Do not supply it as a build requirement or add a second Firebase messaging worker.
- iOS/iPadOS web push acceptance requires a supported Home Screen web app and user permission. Repository fixtures do not prove provider or device delivery.

## Association files and URLs

- Preserve `.well-known/` in web output. The checked-in iOS AASA matches Team `W922PUY77B` and bundle ID `com.example.nalivDelivery`.
- Android `assetlinks.json` is still absent. Obtain the authoritative signing SHA-256 for each installed distribution: **Play App Signing**, not an assumed upload-key fingerprint, for Play installations. Publish the file for package `kz.gradusy24.app` at the real HTTPS hostname as JSON without authentication, redirects or SPA fallback.
- Native filters advertise more URLs than the current Dart router implements. Product must confirm the supported incoming-URL contract before destination routing can be completed; do not mistake successful app launch/domain verification for an opened product/order.

## Firebase Hosting alternative

`firebase.json` keeps the same static release directory, allows association dotfiles, supplies JSON/worker and no-cache headers, and excludes association/OneSignal/legacy-worker paths and `/app-update.json` from SPA fallback. Real static files take precedence over rewrites.

Select the intended Firebase project/site **explicitly** before any deployment. The existing `.firebaserc` default and historical FlutterFire registration metadata name different projects; neither establishes which site owns `app.gradusy24.kz`. Provider registrations are retained, not silently recreated or deleted. No deployment is part of local verification.

Before release, exercise the actual selected host: route refresh, release-refresh headers, AASA JSON, missing association/worker 404s and OneSignal worker paths. The local Hosting emulator checks configuration behavior, not DNS/custom-domain ownership or production delivery.
