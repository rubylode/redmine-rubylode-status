// Signs in to the preview (bin/test-with-widgets preview) and saves /status as one PNG.
// Run with the Playwright of a sibling checkout:  node status_screenshot.mjs <path-of-playwright-core> <output.png>
const [playwrightPath, outputPath] = process.argv.slice(2);
const { chromium } = await import(playwrightPath);
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
await page.goto("http://localhost:3099/login");
await page.fill("#username", "admin");
await page.fill("#password", "admin");
await page.click("#login-submit");
await page.goto("http://localhost:3099/status");
await page.screenshot({ path: outputPath, fullPage: true });
await browser.close();
