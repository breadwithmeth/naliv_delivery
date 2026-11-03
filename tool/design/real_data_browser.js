// OMP Eval: const real = await import('./tool/design/real_data_browser.js');
// Serve the tracked bundle first:  python -m http.server 8794 --bind 127.0.0.1 --directory build/web
// const tab = await real.openRealStore(browser, {name: 'real-b9', store: real.STORES.temirtau});
// await real.tapWhere(tab, (e) => e.name === 'Слабоалкогольные напитки');
// await real.shot(tab, '.figma_cache/render/probe/real_catalog_b9.png');
// await real.assertReadOnly(tab);   // before closing: proves nothing was written
//
// Renders the release build against the live catalogue. An init script installed before the
// app loads rejects every non-GET/HEAD/OPTIONS fetch, XHR and beacon to a non-loopback host
// for the whole life of the tab (including after clicks), so production stays read-only.

// Public stores from GET /api/businesses (city_id: 2 Караганда, 3 Астана, 4 Темиртау).
export const STORES = {
  bukharZhyrau: {id: 11, name: 'Градусы24', address: 'Бухар-Жырау 70, Караганда',
    lat: 49.799416, lon: 73.090596, city_id: 2, city: 'Караганда'},
  shakhterov: {id: 5, name: 'ГРАДУСЫ24', address: 'Шахтеров 52, Караганда',
    lat: 49.788374, lon: 73.1456, city_id: 2, city: 'Караганда'},
  temirtau: {id: 9, name: 'Градусы24', address: 'Мира 86а, Темиртау',
    lat: 50.05, lon: 72.96, city_id: 4, city: 'Темиртау'},
  astana: {id: 7, name: 'ГРАДУСЫ24', address: 'Анет-баба 7/2, Астана',
    lat: 51.134797, lon: 71.38379, city_id: 3, city: 'Астана'},
};

const READ_ONLY_GUARD = `(() => {
  const blocked = (window.__nalivBlocked = window.__nalivBlocked || []);
  const isWrite = (m) => !['GET', 'HEAD', 'OPTIONS'].includes(String(m || 'GET').toUpperCase());
  const isRemote = (u) => {
    try { return new URL(u, location.href).hostname !== '127.0.0.1'; } catch { return true; }
  };
  const nativeFetch = window.fetch.bind(window);
  window.fetch = (input, init = {}) => {
    const url = typeof input === 'string' ? input : input.url;
    const method = init.method || (typeof input === 'object' && input.method) || 'GET';
    if (isWrite(method) && isRemote(url)) {
      blocked.push(method + ' ' + url);
      return Promise.reject(new TypeError('Read-only review blocked ' + method + ' ' + url));
    }
    return nativeFetch(input, init);
  };
  const open = XMLHttpRequest.prototype.open;
  const send = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (method, url, ...rest) {
    this.__naliv = [method, url];
    return open.call(this, method, url, ...rest);
  };
  XMLHttpRequest.prototype.send = function (body) {
    const [method, url] = this.__naliv || [];
    if (isWrite(method) && isRemote(url)) {
      blocked.push(method + ' ' + url);
      this.dispatchEvent(new ProgressEvent('error'));
      return;
    }
    return send.call(this, body);
  };
  navigator.sendBeacon = (url) => {
    if (isRemote(url)) { blocked.push('BEACON ' + url); return false; }
    return true;
  };
})();`;

function preferencesScript(store, theme, city) {
  const prefs = {
    intro_slides_seen: true,
    onboarding_completed: true,
    onboarding_selected_city: city,
    telemetry_consent_enabled: false,
    selected_business_id: store.id,
    selected_business: JSON.stringify(store),
    selected_address: JSON.stringify({address: store.address, city: store.city,
      lat: store.lat, lon: store.lon}),
    theme_mode: theme,
  };
  return `(() => {
    if (location.hostname !== '127.0.0.1') return;
    localStorage.clear();
    for (const [key, value] of Object.entries(${JSON.stringify(prefs)})) {
      localStorage.setItem('flutter.' + key, JSON.stringify(value));
    }
  })();`;
}

/// Opens the served release as a guest of [store]. Reloading the tab resets to this state.
export async function openRealStore(browser, {
  name,
  store = STORES.bukharZhyrau,
  theme = 'light',
  baseUrl = 'http://127.0.0.1:8794/',
  width = 375,
  height = 812,
  onboardingCity = 'Караганда',
} = {}) {
  if (!name) throw new Error('A unique owned tab name is required.');
  if (!['dark', 'light'].includes(theme)) throw new Error('theme must be dark or light');
  const url = new URL(baseUrl);
  if (url.hostname !== '127.0.0.1') throw new Error('Serve the bundle on loopback.');
  const tab = await browser.open({name, viewport: {width, height, deviceScaleFactor: 2},
    app: {tern: false}});
  try {
    await tab.addInitScript(READ_ONLY_GUARD);
    await tab.addInitScript(preferencesScript(store, theme, onboardingCity));
    await tab.run(async ({page}, url, size) => {
      await page.setViewport({...size, deviceScaleFactor: 2});
      await page.setBypassServiceWorker(true);
      await page.setCacheEnabled(false); // a cached older bundle silently hides changes
      await page.goto(url, {waitUntil: 'networkidle0', timeout: 60000});
      await page.waitForSelector('flt-semantics-placeholder', {timeout: 20000});
      await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
      await page.waitForSelector('aria/Открыть корзину', {timeout: 30000});
      await new Promise((resolve) => setTimeout(resolve, 3000));
    }, {args: [url.toString(), {width, height}], timeout: 120});
    return tab;
  } catch (error) {
    await tab.close();
    throw error;
  }
}

/// Throws if the app attempted any write or a write reached the network.
export async function assertReadOnly(tab) {
  const attempted = await tab.evaluate('window.__nalivBlocked || []');
  const sent = (await tab.requests()).filter((request) =>
    !['GET', 'HEAD', 'OPTIONS'].includes(request.method) &&
    !request.url.startsWith('http://127.0.0.1'));
  if (sent.length) {
    throw new Error('Writes reached the network: ' +
      sent.map((request) => `${request.method} ${request.url}`).join(', '));
  }
  return {attemptedAndBlocked: attempted, errors: await tab.errors()};
}

/// Settles animations and images, then saves a viewport PNG at DPR 2.
export async function shot(tab, path, {settleMs = 1800} = {}) {
  return await tab.run(async ({page}, path, settleMs) => {
    await page.mouse.move(2, 2); // drop hover/tooltips
    await new Promise((resolve) => setTimeout(resolve, settleMs));
    await page.screenshot({path, fullPage: false});
    return path;
  }, {args: [path, settleMs], timeout: 90});
}

/// Clicks the first semantics node matching [predicate]({role, name}). Flutter rebuilds
/// invalidate handles, so this observes fresh every time.
export async function tapWhere(tab, predicate, {settleMs = 1600} = {}) {
  const {elements} = await tab.observe({compact: true});
  const match = elements.find(predicate);
  if (!match) {
    throw new Error('No matching node. Visible: ' +
      elements.slice(0, 30).map((element) => element.name).join(' | '));
  }
  await tab.id(match.id).click();
  await new Promise((resolve) => setTimeout(resolve, settleMs));
}

export async function scroll(tab, deltaY, {x = 187, y = 450} = {}) {
  await tab.run(async ({page}, deltaY, x, y) => {
    await page.mouse.move(x, y);
    await page.mouse.wheel({deltaY});
    await new Promise((resolve) => setTimeout(resolve, 900));
  }, {args: [deltaY, x, y], timeout: 30});
}

/// Wheel-scrolls the current screen down then up while sampling requestAnimationFrame
/// intervals. Compare before/after on the same build host: headless Chromium renders in
/// software, so absolute numbers are pessimistic, but jank counts (> 25 ms) are comparable.
export async function measureScroll(tab, {steps = 24, delta = 220, x = 187, y = 450} = {}) {
  return await tab.run(async ({page}, steps, delta, x, y) => {
    await page.evaluate(() => {
      window.__frames = [];
      window.__sampling = true;
      let last = performance.now();
      const tick = (time) => {
        window.__frames.push(time - last);
        last = time;
        if (window.__sampling) requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
    });
    await page.mouse.move(x, y);
    for (let index = 0; index < steps; index++) {
      await page.mouse.wheel({deltaY: index < steps / 2 ? delta : -delta});
      await new Promise((resolve) => setTimeout(resolve, 60));
    }
    await new Promise((resolve) => setTimeout(resolve, 400));
    const frames = await page.evaluate(() => {
      window.__sampling = false;
      return window.__frames.slice(2);
    });
    const sorted = [...frames].sort((a, b) => a - b);
    const at = (p) => +sorted[Math.min(sorted.length - 1, Math.floor(p * sorted.length))]
        .toFixed(1);
    return {frames: frames.length, p50: at(.5), p90: at(.9), p99: at(.99),
      over25: frames.filter((value) => value > 25).length,
      over50: frames.filter((value) => value > 50).length};
  }, {args: [steps, delta, x, y], timeout: 90});
}

/// Lays PNGs out in a labelled grid so a whole pass can be reviewed in one image.
/// Read the sheet, then open any suspect screen at full size before judging it.
export async function contactSheet(browser, files, outPath, {
  columns = 4, cellWidth = 300, labels = [],
} = {}) {
  const tab = await browser.open({name: `sheet-${Date.now()}`, app: {tern: false},
    viewport: {width: columns * cellWidth, height: 800, deviceScaleFactor: 1}});
  try {
    return await tab.run(async ({page}, files, outPath, columns, cellWidth, labels) => {
      const fs = await import('node:fs');
      const cells = files.map((file, index) => {
        const data = fs.readFileSync(file).toString('base64');
        const label = labels[index] ?? file.split(/[\\/]/).pop();
        return `<figure><figcaption>${label}</figcaption>` +
          `<img src="data:image/png;base64,${data}"></figure>`;
      }).join('');
      await page.setContent(`<style>
        body{margin:0;font:14px sans-serif;display:grid;
          grid-template-columns:repeat(${columns},${cellWidth}px)}
        figure{margin:0;padding:4px}figcaption{height:20px;overflow:hidden}
        img{width:100%;display:block}</style>${cells}`);
      await page.evaluate(() => Promise.all([...document.images].map((image) =>
        image.complete ? null : new Promise((resolve) => { image.onload = resolve; }))));
      await page.screenshot({path: outPath, fullPage: true});
      return outPath;
    }, {args: [files, outPath, columns, cellWidth, labels], timeout: 60});
  } finally {
    await tab.close();
  }
}
