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
  const assertGeometry = audit => {
    assert.equal(audit.environmentMatches, true, JSON.stringify(audit));
    assert.ok(!audit.issues.some(i => ["document-horizontal-overflow", "small-target", "nowrap-contract-candidate",
      "outside-viewport", "clipped-by-ancestor", "clipped-control"].includes(i.type)), JSON.stringify(audit.issues));
    assert.equal(audit.counts.nowrapInspected, 4, "summary and three horizontal links must be measured");
  };
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
          const audit = await measureUI(page, { expectedWidth: width, expectedMobile: mobile, expectedMode: mode });
          assertGeometry(audit);
          // Geometry covers rendered DOM; also visit the lower section to check actual viewport layout.
          await page.focus("#preview-save");
          const workAudit = await measureUI(page, { expectedWidth: width, expectedMobile: mobile, expectedMode: mode });
          assertGeometry(workAudit);
          rows.push({ theme, mode, width, actual: audit.actual.width, touch: audit.actual.coarsePointer,
            measuredControls: workAudit.counts.inspected, measuredNowrap: workAudit.counts.nowrapInspected, visitedWork: true });
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
    await page.waitForFunction(() => document.querySelector(".kit-tab:last-child").getAttribute("aria-current") === "location");
    await configureViewport(page, { width: 320, mobile: true });
    await page.goto(url);
    await page.evaluate(() => { document.documentElement.style.fontSize = "200%"; });
    assertGeometry(await measureUI(page, { expectedWidth: 320, expectedMobile: true }));
    await tap(page, "#menu-toggle");
    await page.waitForFunction(() => document.querySelector(".preview-menu").open);
    await page.keyboard.press("Escape");
    assert.equal(await page.evaluate(() => !document.querySelector(".preview-menu").open), true);
    // A regression below the first viewport must be detected without relying on a screenshot.
    await page.goto(url);
    await page.evaluate(() => {
      const s = document.createElement("style");
      s.textContent = ".kit-tab{white-space:normal!important;flex-shrink:1!important}.kit-tabs{inline-size:auto!important} #preview-save{min-height:0;height:24px;padding:0;font-size:12px}";
      document.head.append(s);
    });
    const belowFold = await measureUI(page, { expectedWidth: 320, expectedMobile: true });
    assert.ok(belowFold.issues.some(i => i.type === "nowrap-contract-candidate"));
    assert.ok(belowFold.issues.some(i => i.type === "small-target" && i.id === "preview-save"));
    await page.goto(url);
    const closedMenu = await measureUI(page, { controlSelector: ".preview-menu a", nowrapSelector: ".preview-menu a" });
    assert.equal(closedMenu.counts.inspected, 0);
    assert.equal(closedMenu.counts.hidden, 3);
    assert.equal(closedMenu.issues.length, 0);
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
    await page.evaluate(() => {
      document.documentElement.style.overflowX = "hidden";
      document.body.style.overflowX = "hidden";
    });
    const masked = await measureUI(page, { expectedWidth: 390, expectedMobile: true });
    assert.ok(masked.issues.some(i => i.type === "clipped-by-ancestor" || i.type === "outside-viewport"));
    return { rows, colors, touchMenu: true, keyboardMenuAndLastLink: true, systemMode: true, brokenFixtureDetected: true,
      enlargedText: true, belowFoldRegression: true, closedDetailsExcluded: true, maskedOverflowDetected: true };
  } finally {
    await resetViewport(page);
  }
}
