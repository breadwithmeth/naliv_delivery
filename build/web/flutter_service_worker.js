'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "8bc01b1c47a5f003e406d3ce067bcd3e",
"version.json": "eb0cf35a99e85f5782069790f3d3a8bf",
"index.html": "192bdaf803883e4f9f93755f1a7d6066",
"/": "192bdaf803883e4f9f93755f1a7d6066",
"50x.html": "edc3f3dfd8daf4cf602837224dc6ff38",
"main.dart.js": "5ab81861665b360e9e2b43e32fc04cce",
".well-known/apple-app-site-association": "d7ecf9fb4dd598bbc27f5e8b10527817",
"404.html": "9a5bf6cebdfd99ed2243d52119f1a4e5",
"onesignal/OneSignalSDKWorker.js": "8e3ee21f321e4291e1671535f04679c8",
"onesignal/OneSignalSDKUpdaterWorker.js": "8e3ee21f321e4291e1671535f04679c8",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"favicon.png": "617ebc252c68d2d1ec96578c206d88fe",
"icons/Icon-192.png": "407e063dc46c579e5ba1cdd974af73a0",
"icons/Icon-maskable-192.png": "407e063dc46c579e5ba1cdd974af73a0",
"icons/Icon-maskable-512.png": "f1fe0615eb6a977857346d5ce9a3fcd8",
"icons/Icon-512.png": "f1fe0615eb6a977857346d5ce9a3fcd8",
"manifest.json": "5ed72395438f5417f2bfe0cf0cdf8750",
"assets/NOTICES": "6e53f7822cfc8fcb2f7a6761b2f70b43",
"assets/FontManifest.json": "28a46ec4b929294c48805a716163793a",
"assets/AssetManifest.bin.json": "42f4526ea05d5decfe324ab13662f3a5",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/flutter_map/lib/assets/flutter_map_logo.png": "208d63cc917af9713fc9572bd5c09362",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/AssetManifest.bin": "011e22885f0e9d3f7ba3aa7e7c8d8f15",
"assets/fonts/MaterialIcons-Regular.otf": "a404606604a9f27834d2101e44f5c9df",
"assets/assets/icons/design/search.svg": "384f4ebd6dc8a446195af2491320f103",
"assets/assets/icons/design/bag_happy.svg": "2af1d54b61dbb264ec407811bc91ae94",
"assets/assets/icons/design/repeat.svg": "2b9fdaa19dae7e239a0b5b2cf4f7104f",
"assets/assets/icons/design/wordmark.svg": "5138a584551c57c131c79a2f39851c82",
"assets/assets/icons/design/bonus_star.svg": "a136e398e296bc48667e35e8f5a19765",
"assets/assets/icons/design/discount_shape.svg": "0f76dc727bd66ea4ffa8d0b17262a7bb",
"assets/assets/icons/design/user.svg": "d1ab88bac421b8f60c48b9e3cd8f86a3",
"assets/assets/icons/design/shop.svg": "ade167ed849f50de0dada977dd630777",
"assets/assets/icons/design/logout.svg": "e889250f6c6972734f98bf734ad1f0cc",
"assets/assets/icons/design/theme.svg": "d1296a24bc412eca44a687633bc386e0",
"assets/assets/icons/design/fire.svg": "f89f608a6e8ea7bef473102d282927c0",
"assets/assets/icons/design/cart.svg": "b63512bd0bcb126a3159ad892180c27c",
"assets/assets/icons/design/bell.svg": "46a9c9d3479072e3d1f773ef05702504",
"assets/assets/icons/design/support.svg": "6440db8e1dac0b01d38c77b8de3ac4c0",
"assets/assets/icons/design/check.svg": "313f56898ea7cea4f1bee689deb1a3aa",
"assets/assets/icons/design/orders.svg": "9feb6601c1b2c4c36824adab10609aab",
"assets/assets/icons/design/bag_timer.svg": "cfbcdd1a192e5dd730c9000dbb6f247a",
"assets/assets/icons/design/back.svg": "7f9ae4751d166238872010cc40b6f707",
"assets/assets/icons/design/cart_fab.svg": "e680370b4ff9c67f76c3232036367629",
"assets/assets/icons/design/addresses.svg": "e5dd80bd4ffb8322c2981ed31587a6dd",
"assets/assets/icons/design/star.svg": "72fb58de71c3a91a5867f0655c742e55",
"assets/assets/icons/design/faq.svg": "ec18bc6496ea154c9306292283376178",
"assets/assets/icons/design/analytics.svg": "02b7e8e6ba561ff7ee027d5b7d806022",
"assets/assets/icons/design/phone.svg": "5e30b8ce1d70974c7f4e2beb758ac372",
"assets/assets/icons/design/location.svg": "591647eee02c40b69385e9264ac6afb8",
"assets/assets/icons/design/logo.svg": "dafcaa4fe2b7b6c5f8d61fa6e21a1241",
"assets/assets/icons/design/avatar.svg": "34ba7ccfb388ff84958ce8acff0e104b",
"assets/assets/icons/design/cards.svg": "b428b916528b1c40a1e34cd473ea871c",
"assets/assets/icons/design/certificates.svg": "a202aeea3a8058ef9ba0239e6da451f6",
"assets/assets/icons/design/heart.svg": "46cf1253f312c7df008a8da8a5426ca1",
"assets/assets/icons/kaspi/pay_compact.svg": "42fa67d2b5eac5f0bda27260a536c5a8",
"assets/assets/icons/kaspi/compact.svg": "9f042afd4c8e42bb9fa6d2b5f0174eaa",
"assets/assets/icons/kaspi/gold.svg": "696651ae9beb05925a99727d63de4e58",
"assets/assets/icons/kaspi/logo_white.svg": "6dfac7805fe8bfce121bc75cd2e74f8a",
"assets/assets/icons/kaspi/logo.svg": "20fa44a28d6675bd50fab1bbe97fbdfa",
"assets/assets/fonts/TikTokSans/TikTokSans-Variable.ttf": "067de9b95f6eef5870f756183b3ae0d8",
"canvaskit/wimp.wasm": "9242e201530449825b5645ed3d5af22c",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/wimp.js": "40195751139ab9e4b7c62b19c420f63b",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/wimp.js.symbols": "e9ac11318ebff9b7ad24ca7841f69b3f",
"canvaskit/experimental_webparagraph/canvaskit.js.symbols": "0c6d97b036dffdc0f4bc4552ae7b5c9d",
"canvaskit/experimental_webparagraph/canvaskit.js": "230c0e2b182dcd1061c06c2fe7b64b5f",
"canvaskit/experimental_webparagraph/canvaskit.wasm": "e008e87c245b0718932b34e9a15be803",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
