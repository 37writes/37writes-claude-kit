// Call from ego-browser nodejs with an assigned Page and a local preview.html URL.
import assert from "node:assert/strict";
import { configureViewport, measureUI, resetViewport } from "./ego-audit.mjs";

async function tap(page, selector) {
  const point = await page.evaluate(selector => {
    const el = document.querySelector(selector), r = el.getBoundingClientRect();
    const x = r.x + r.width / 2, y = r.y + r.height / 2;
    if (x < 0 || y < 0 || x >= innerWidth || y >= innerHeight || !el.contains(document.elementFromPoint(x, y)))
      throw new Error("touch target not visible");
    return { x, y };
  }, selector);
  await page.cdp("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: [{ ...point, radiusX: 1, radiusY: 1, force: 1 }] });
  await page.cdp("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
}

export async function runSmoke(page, url) {
  const rows = [], colors = [];
  try {
    for (const theme of ["neutral", "paper"]) {
      for (const mode of ["light", "dark"]) {
        // Includes core's 640px and preview's 768px breakpoints ±1.
        for (const width of [320, 360, 390, 430, 639, 640, 641, 767, 768, 769, 1280]) {
          const mobile = width < 768;
          await configureViewport(page, { width, mobile, mode });
          await page.goto(url);
          await page.evaluate(({ theme, mode }) => {
            document.documentElement.dataset.kitTheme = theme;
            document.documentElement.dataset.kitMode = mode;
          }, { theme, mode });
          const audit = await measureUI(page, { expectedWidth: width, expectedMobile: mobile, expectedMode: mode, nowrapSelector: ".kit-tab" });
          assert.equal(audit.environmentMatches, true, JSON.stringify(audit));
          assert.ok(!audit.issues.some(i => ["document-horizontal-overflow", "small-target", "nowrap-contract-candidate"].includes(i.type)), JSON.stringify(audit.issues));
          rows.push({ theme, mode, width, actual: audit.actual.width, touch: audit.actual.coarsePointer });
          if (width === 1280) {
            colors.push(await page.evaluate(({ theme, mode }) => {
              const s = getComputedStyle(document.documentElement);
              const names = ["bg", "surface", "surface-alt", "text", "muted", "control-border", "accent", "on-accent", "danger", "success", "focus"];
              return { theme, mode, tokens: Object.fromEntries(names.map(n => [n, s.getPropertyValue(`--kit-${n}`).trim()])) };
            }, { theme, mode }));
          }
        }
      }
    }
    await configureViewport(page, { width: 390, mobile: true });
    await page.goto(url);
    await tap(page, "#menu-toggle");
    await page.waitForFunction(() => document.querySelector(".preview-menu").open);
    await tap(page, '.preview-menu a[href="#intro"]');
    await page.waitForFunction(() => !document.querySelector(".preview-menu").open && location.hash === "#intro");
    await page.goto(url);
    await page.focus("#menu-toggle");
    await page.keyboard.press("Enter");
    await page.waitForFunction(() => document.querySelector(".preview-menu").open);
    await page.keyboard.press("Escape");
    assert.equal(await page.evaluate(() => !document.querySelector(".preview-menu").open && document.activeElement.id === "menu-toggle"), true);
    await page.focus(".kit-tab:first-child");
    await page.keyboard.press("Tab");
    await page.keyboard.press("Tab");
    assert.equal(await page.evaluate(() => document.activeElement === document.querySelector(".kit-tab:last-child") && document.querySelector(".kit-scroll").scrollLeft > 0), true);
    await page.keyboard.press("Enter");
    await page.waitForFunction(() => location.hash === "#intro");
    // Test explicit appearance takes precedence over media; then system follows media.
    await configureViewport(page, { width: 390, mobile: true, mode: "dark" });
    await page.goto(url);
    assert.equal(await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue("--kit-bg").trim()), "#f5f5f7");
    await page.evaluate(() => document.documentElement.removeAttribute("data-kit-mode"));
    assert.equal(await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue("--kit-bg").trim()), "#18181b");
    await page.goto(`${url}?broken=1`);
    const broken = await measureUI(page, { expectedWidth: 390, expectedMobile: true });
    assert.ok(broken.issues.some(i => i.type === "document-horizontal-overflow"));
    assert.ok(broken.issues.some(i => i.type === "small-target"));
    assert.equal(broken.environmentMatches, false);
    return { rows, colors, touchMenu: true, keyboardMenuAndLastLink: true, systemMode: true, brokenFixtureDetected: true };
  } finally {
    await resetViewport(page);
  }
}
