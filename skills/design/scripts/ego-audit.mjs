// Read-only measurements through an existing ego Page. Never launches a browser.
export async function configureViewport(page, { width, height = 844, mobile = true, mode = "light" }) {
  if (!Number.isInteger(width) || width < 1 || !Number.isInteger(height) || height < 1)
    throw new Error("positive integer viewport dimensions required");
  if (!["light", "dark"].includes(mode)) throw new Error("mode must be light or dark");
  await page.cdp("Emulation.setDeviceMetricsOverride", { width, height, deviceScaleFactor: 1, mobile });
  await page.cdp("Emulation.setTouchEmulationEnabled", { enabled: mobile, maxTouchPoints: 1 });
  await page.cdp("Emulation.setEmulatedMedia", { features: [{ name: "prefers-color-scheme", value: mode }] });
}

export async function resetViewport(page) {
  const results = await Promise.allSettled([
    page.cdp("Emulation.clearDeviceMetricsOverride", {}),
    page.cdp("Emulation.setTouchEmulationEnabled", { enabled: false }),
    page.cdp("Emulation.setEmulatedMedia", { features: [] }),
  ]);
  const failed = results.filter(r => r.status === "rejected");
  if (failed.length) throw new Error(`ego emulation reset failed: ${failed.map(r => String(r.reason)).join("; ")}`);
}

export async function measureUI(page, options = {}) {
  const config = {
    expectedWidth: options.expectedWidth ?? null,
    expectedMobile: options.expectedMobile ?? null,
    expectedMode: options.expectedMode ?? null,
    controlSelector: options.controlSelector ?? "button, input:not([type=hidden]), select, textarea, [role=tab], summary",
    nowrapSelector: options.nowrapSelector ?? "",
    minTarget: options.minTarget ?? 44,
    limit: options.limit ?? 500,
  };
  if (!Number.isInteger(config.limit) || config.limit < 1 || config.limit > 5000)
    throw new Error("limit must be an integer from 1 to 5000");
  return page.evaluate(async (c) => {
    await document.fonts.ready;
    await new Promise(resolve => requestAnimationFrame(resolve));
    const round = n => Math.round(n * 100) / 100;
    const visible = el => {
      const r = el.getBoundingClientRect(), s = getComputedStyle(el);
      return r.width > 0 && r.height > 0 && s.visibility !== "hidden" && s.display !== "none"
        && !el.closest("[inert]") && r.bottom > 0 && r.top < innerHeight;
    };
    const identify = el => ({
      tag: el.tagName.toLowerCase(), id: el.id || null,
      classes: typeof el.className === "string" ? el.className : "",
      label: (el.getAttribute("aria-label") || el.textContent || "").trim().slice(0, 100),
    });
    const issues = [];
    const selected = [...document.querySelectorAll(c.controlSelector)];
    const nowrap = c.nowrapSelector ? [...document.querySelectorAll(c.nowrapSelector)] : [];
    let inspected = 0;
    for (const el of selected.slice(0, c.limit)) {
      if (!visible(el)) continue;
      inspected++;
      const r = el.getBoundingClientRect();
      const box = { x: round(r.x), y: round(r.y), width: round(r.width), height: round(r.height) };
      if (r.width < c.minTarget - .5 || r.height < c.minTarget - .5)
        issues.push({ type: "small-target", ...identify(el), box });
      if (r.left < -1 || r.right > innerWidth + 1)
        issues.push({ type: "outside-viewport-or-scroll-container", ...identify(el), box });
      if (el.scrollWidth > el.clientWidth + 1 && ["hidden", "clip"].includes(getComputedStyle(el).overflowX))
        issues.push({ type: "clipped-control", ...identify(el), box });
    }
    for (const el of nowrap.slice(0, c.limit)) {
      if (!visible(el)) continue;
      const range = document.createRange();
      range.selectNodeContents(el);
      const ys = [];
      for (const r of range.getClientRects()) {
        if (r.width && r.height && !ys.some(y => Math.abs(y - r.top) < 3)) ys.push(r.top);
      }
      if (ys.length > 1) issues.push({ type: "nowrap-contract-candidate", ...identify(el), textRows: ys.length });
    }
    const actual = {
      width: innerWidth, height: innerHeight, clientWidth: document.documentElement.clientWidth,
      scrollWidth: document.documentElement.scrollWidth, dpr: devicePixelRatio,
      visualWidth: visualViewport?.width ?? null, scale: visualViewport?.scale ?? null,
      coarsePointer: matchMedia("(pointer: coarse)").matches, maxTouchPoints: navigator.maxTouchPoints,
      mediaDark: matchMedia("(prefers-color-scheme: dark)").matches,
    };
    const mismatches = [];
    if (c.expectedWidth !== null && Math.abs(actual.width - c.expectedWidth) > 1) mismatches.push("viewport-width");
    if (c.expectedMobile === true && (!actual.coarsePointer || actual.maxTouchPoints < 1)) mismatches.push("touch-environment");
    if (c.expectedMode !== null && actual.mediaDark !== (c.expectedMode === "dark")) mismatches.push("color-scheme-media");
    const overflow = Math.max(actual.scrollWidth - actual.clientWidth, c.expectedWidth === null ? 0 : actual.scrollWidth - c.expectedWidth);
    if (overflow > 1) issues.push({ type: "document-horizontal-overflow", pixels: round(overflow) });
    return {
      url: location.href, requested: c, actual, environmentMatches: mismatches.length === 0, mismatches,
      counts: { controls: selected.length, inspected, nowrap: nowrap.length },
      truncated: selected.length > c.limit || nowrap.length > c.limit,
      fonts: { status: document.fonts.status, faces: [...document.fonts].map(f => ({ family: f.family, status: f.status })) },
      issues,
      limitations: ["DOM candidates only; not a pass/fail verdict", "viewport slice; no iframe/shadow DOM scan",
        "does not prove touch actions, occlusion, keyboard behavior, actual font use, or real-device compatibility"],
    };
  }, config);
}
