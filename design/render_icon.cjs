// Renders design/icon.svg to the app's PNG icons (needs Playwright).
// Usage: node design/render_icon.cjs design/icon.svg app/web/icons && mv app/web/icons/favicon.png app/web/
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const [svgPath, out] = process.argv.slice(2);
  const svg = fs.readFileSync(svgPath, 'utf8');
  const b = await chromium.launch();
  const p = await b.newPage();
  // [file, size, scale of artwork (maskable icons keep a safe zone)]
  const jobs = [
    ['Icon-512.png', 512, 1], ['Icon-192.png', 192, 1], ['favicon.png', 32, 1],
    ['Icon-maskable-512.png', 512, 1], ['Icon-maskable-192.png', 192, 1], 
  ];
  for (const [file, size, scale] of jobs) {
    await p.setViewportSize({ width: size, height: size });
    const inner = Math.round(size * scale), pad = (size - inner) / 2;
    await p.setContent(`<html><body style="margin:0;background:#14111C">
      <div style="position:absolute;left:${pad}px;top:${pad}px;width:${inner}px;height:${inner}px">${svg.replace('<svg ', `<svg width="${inner}" height="${inner}" `)}</div></body></html>`);
    await p.screenshot({ path: `${out}/${file}` });
  }
  await b.close();
})();
