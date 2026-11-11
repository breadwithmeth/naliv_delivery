// OMP Eval: const fixtures = await import('./tool/design/fixture_browser.js');
// const tab = await fixtures.openFixture(browser, {name: 'catalog-review', surface: 'catalog'});
// Use fresh tab.observe()/tab.id() handles for actions; fixtures.capture(tab, path) resets DPI.
export async function openFixture(browser, {
  name,
  baseUrl = 'http://127.0.0.1:8790/',
  surface = 'active_route',
  theme = 'dark',
  width = 375,
  height = 812,
  scale = 1,
  keyboard = 0,
  guest = false,
  cards = 'loaded',
  payment = 'completed',
  updates = 'off',
} = {}) {
  if (!name) throw new Error('A unique owned tab name is required.');
  const url = new URL(baseUrl);
  if (url.protocol !== 'http:' || url.hostname !== '127.0.0.1' ||
      url.username || url.password) {
    throw new Error('Fixture browser accepts only unauthenticated loopback HTTP.');
  }
  if (!['dark', 'light'].includes(theme) || !Number.isFinite(width) || width <= 0 ||
      !Number.isFinite(height) || height <= 0 || !Number.isFinite(scale) || scale <= 0 ||
      !Number.isFinite(keyboard) || keyboard < 0) {
    throw new Error('Invalid fixture geometry, theme, text scale, or keyboard inset.');
  }
  url.search = new URLSearchParams({
    surface, theme, scale: String(scale), keyboard: String(keyboard),
    cards, payment, updates, ...(guest ? {guest: '1'} : {}),
  }).toString();
  const viewport = {width, height, deviceScaleFactor: 2};
  const tab = await browser.open({
    name,
    viewport,
    allowed_domains: ['127.0.0.1', 'www.gstatic.com', 'fonts.gstatic.com'],
    app: {tern: false},
  });
  try {
    await tab.run(async ({page}, url, viewport) => {
      await page.setBypassServiceWorker(true);
      await page.setCacheEnabled(false);
      await page.setViewport(viewport);
      await page.goto(url);
      await page.waitForSelector('flt-semantics-placeholder', {timeout: 15000});
      await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
      await page.waitForSelector('[role="button"]', {timeout: 15000});
      const invalid = await page.evaluate(() =>
        document.querySelector('[aria-label*="Invalid fixture configuration"]') !== null ||
        document.body.textContent.includes('Invalid fixture configuration'));
      if (invalid) {
        throw new Error('Invalid fixture configuration; inspect the rejected URL selectors.');
      }
    }, {args: [url.toString(), viewport], timeout: 40});
    return tab;
  } catch (error) {
    await tab.close();
    throw error;
  }
}

export async function capture(tab, path, {width = 375, height = 812} = {}) {
  if (!Number.isFinite(width) || width <= 0 || !Number.isFinite(height) || height <= 0) {
    throw new Error('Screenshot dimensions must be positive finite numbers.');
  }
  return await tab.run(async ({page}, path, width, height) => {
    // Do this immediately before every PNG: browser defaults/DPI can change between calls.
    await page.setViewport({width, height, deviceScaleFactor: 2});
    const bytes = await page.screenshot({path, fullPage: false});
    const png = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const actualWidth = png.getUint32(16);
    const actualHeight = png.getUint32(20);
    if (actualWidth !== width * 2 || actualHeight !== height * 2) {
      throw new Error(`Screenshot is ${actualWidth}×${actualHeight}, expected ${width * 2}×${height * 2}.`);
    }
    return {path, logicalWidth: width, logicalHeight: height, dpr: 2,
      pixelWidth: actualWidth, pixelHeight: actualHeight};
  }, {args: [path, width, height], timeout: 30});
}
