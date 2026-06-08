'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "0aa8a84ac3c7fd7a0ad24d35942f1eab",
"version.json": "aa00453fc7ad63e383a0dad1cb9ceeaf",
"splash/img/light-background.png": "2353ae0a32d84733e6c2da6db68abfb6",
"index.html": "8862801239a5400fe36fc4091cc7b9ba",
"/": "8862801239a5400fe36fc4091cc7b9ba",
"50x.html": "edc3f3dfd8daf4cf602837224dc6ff38",
"main.dart.js": "221ab9f4eef0f010ee0e6e5d1e6d34e3",
".well-known/apple-app-site-association": "d7ecf9fb4dd598bbc27f5e8b10527817",
"404.html": "9a5bf6cebdfd99ed2243d52119f1a4e5",
"onesignal/OneSignalSDKWorker.js": "8e3ee21f321e4291e1671535f04679c8",
"onesignal/OneSignalSDKUpdaterWorker.js": "8e3ee21f321e4291e1671535f04679c8",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"favicon.png": "bd349303c69f15656d16932592a85c77",
"icons/Icon-192.png": "d1e57ea887ebc90151decdc8ef9856a4",
"icons/Icon-maskable-192.png": "d1e57ea887ebc90151decdc8ef9856a4",
"icons/Icon-maskable-512.png": "949df64f6638e8feef34055917d96249",
"icons/Icon-512.png": "949df64f6638e8feef34055917d96249",
"manifest.json": "5ed72395438f5417f2bfe0cf0cdf8750",
"assets/NOTICES": "a70a5c9ee877ee37e7760ed887cbc458",
"assets/FontManifest.json": "46e4668f6b118403be3494d3859e2b90",
"assets/AssetManifest.bin.json": "1dea4ab367f532fe4ff94be280d44eba",
"assets/packages/flutter_map/lib/assets/flutter_map_logo.png": "208d63cc917af9713fc9572bd5c09362",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/AssetManifest.bin": "005c9908326158abcdcaf40a7e54add0",
"assets/fonts/MaterialIcons-Regular.otf": "20e3548a187c7436fe93b461e2cc253a",
"assets/assets/txt.svg": "84db7ddcc9aa78fa5a56df256bd98d97",
"assets/assets/agreements/nds.md": "1e1223131430014750335b8da2c3e5eb",
"assets/assets/agreements/privacy.md": "ff1887bdd759cb67232df3bcf207ca2a",
"assets/assets/agreements/offer.md": "b5a964ffb4acd8d6f3137e510a7b3520",
"assets/assets/agreements/links.md": "65377e37a8a807411eec26f2e0e25f17",
"assets/assets/agreements/returnPolicy.md": "e2c51a204d6c8a76a43427a2f55d9fc3",
"assets/assets/vectors/cocktail.png": "daa18e901a64b534a1e5474f710508e9",
"assets/assets/vectors/cigarette.png": "0461be1b3830db9cd74dcef1c9e370a3",
"assets/assets/vectors/mineral-water.png": "68283296dc1e72ec081d1417d1f330b0",
"assets/assets/vectors/other.png": "c5c9717343933fccb4af1cf86e6aca0f",
"assets/assets/vectors/vodka.png": "810fccf1a388e5028e5021a3edfd78b6",
"assets/assets/vectors/fruit.png": "deb576fd8545598bc1a142b9e63832c8",
"assets/assets/vectors/chocolate.png": "aa87d1655f32c308785b9fbbce3d515b",
"assets/assets/s/mc.png": "fe807bce353d0bc60f09a60409236255",
"assets/assets/s/visa.png": "de8246ea4ee34b14079a48cdf5a46f35",
"assets/assets/s/s1.jpg": "cf32be686ae9bf427889a4790515e71d",
"assets/assets/s/s3.jpg": "fed94166997b0d885fb38c4d3b179f38",
"assets/assets/s/s2.jpg": "10d3410bfb78bb890fc017b83f9cd4b0",
"assets/assets/naliv_logo_loading.png": "0d1cddd4ffe8c67eefd48ec3aee60209",
"assets/assets/property_icons/litr.png": "3dc5b625df748bd1cdce1a402ef3d494",
"assets/assets/property_icons/percent.png": "1473dd608f3fcb5d45853a8c831c2eff",
"assets/assets/icons/home_active.png": "8c1a9b91a335f0584fd768feb80d5950",
"assets/assets/icons/flash.png": "f6241e897d08dbaaeeb15045af917e32",
"assets/assets/icons/cart.png": "387bdbca6171bd71003e4029f595805f",
"assets/assets/icons/profile_active.png": "6e94f588d8ae20b36694283ae07c2f3b",
"assets/assets/icons/fire.png": "8246d640944db032e6df33ded58c5f54",
"assets/assets/icons/home.png": "363d8fde320dd454c02af91ad342444a",
"assets/assets/icons/cart_active.png": "eef8170f5de7236e2aa437f3964bcfbb",
"assets/assets/icons/like_active.png": "2faa9d5353044c2952b8d90b29b880eb",
"assets/assets/icons/wine.png": "fba55e2c9e229d3bcf51fbbeaa544caf",
"assets/assets/icons/like.png": "2b62c34c98af25fe3dc914f8619adc50",
"assets/assets/icons/search.png": "f436f3d47ca19c1ebb86c5636fa088de",
"assets/assets/icons/gift.png": "f630e11bf88fef25e1b05f931140e340",
"assets/assets/icons/profile.png": "260cfe84163afd30908a675b13f5a77d",
"assets/assets/icons/fav.png": "9bf3d486e4acf28ce235f21dee70f32c",
"assets/assets/naliv_logo.png": "4ac8e6f7b7ba8fb8f12863d7ab95075d",
"assets/assets/fonts/Montserrat_Alternates/MontserratAlternates-Bold.ttf": "dec15f4454da4c3dcdba85a36c9f9a37",
"assets/assets/fonts/Montserrat_Alternates/MontserratAlternates-Black.ttf": "4ee31e1bdfd4b73e58b03be7235c6b13",
"assets/assets/fonts/Montserrat_Alternates/MontserratAlternates-Medium.ttf": "4c61e408402414f36f5c3a06ecc5915b",
"assets/assets/fonts/Montserrat_Alternates/MontserratAlternates-Regular.ttf": "aed416691ba9afb1590d9ddf220f5996",
"assets/assets/fonts/Montserrat_Alternates/MontserratAlternates-SemiBold.ttf": "049fdc5014564a1f21293fe11e108bcc",
"assets/assets/fonts/Montserrat_Alternates/MontserratAlternates-ExtraBold.ttf": "bb1218e7fc385a9bff7b79b2b096ab09",
"assets/assets/fonts/Raleway/Raleway-Italic-VariableFont_wght.ttf": "a454a97a31574945baa438773b6738a0",
"assets/assets/fonts/Raleway/Raleway-VariableFont_wght.ttf": "029b34594de6218e9aaa8b95854f30fe",
"assets/assets/logo_new.svg": "e3e7f93d2958303983846acac89bcf6b",
"assets/assets/gradusy_logo_loading.png": "ca2b09678dd03cf847e75e871310dbe2",
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
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
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
