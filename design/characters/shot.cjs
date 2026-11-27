const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 600, height: 800 } });
  for (const f of process.argv.slice(2)) {
    await p.goto('file://' + f);
    await p.screenshot({ path: f.replace(/\.svg$/, '.png') });
  }
  await b.close();
})();
