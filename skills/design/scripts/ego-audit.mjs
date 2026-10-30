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
    controlSelector: options.controlSelector ?? "button, input:not([type=hidden]), select, textarea, [role=tab], .kit-tab, summary",
    nowrapSelector: options.nowrapSelector ?? "summary, [role=tab], .kit-tab",
    minTarget: options.minTarget ?? 44,
    limit: options.limit ?? 500,
  };
  if (!Number.isInteger(config.limit) || config.limit < 1 || config.limit > 5000)
    throw new Error("limit must be an integer from 1 to 5000");
  return page.evaluate(async (c) => {
    await document.fonts.ready;
    await new Promise(resolve => requestAnimationFrame(resolve));
    const round = n => Math.round(n * 100) / 100;
    const rendered = el => {
      const r = el.getBoundingClientRect(), s = getComputedStyle(el);
      if (typeof el.checkVisibility === "function" && !el.checkVisibility({ contentVisibilityAuto: true, visibilityProperty: true, opacityProperty: true })) return false;
      // Native closed details can retain descendant rectangles despite not painting them.
      for (let p = el.parentElement; p; p = p.parentElement) {
        if (p.tagName === "DETAILS" && !p.open) {
          const summary = p.querySelector(":scope > summary");
          if (!summary?.contains(el)) return false;
        }
      }
      return r.width > 0 && r.height > 0 && s.visibility !== "hidden" && s.display !== "none" && !el.closest("[inert]");
    };
    const identify = el => ({
      tag: el.tagName.toLowerCase(), id: el.id || null,
      classes: typeof el.className === "string" ? el.className : "",
      label: (el.getAttribute("aria-label") || el.textContent || "").trim().slice(0, 100),
    });
    const issues = [];
    const selected = [...document.querySelectorAll(c.controlSelector)];
    const nowrap = c.nowrapSelector ? [...document.querySelectorAll(c.nowrapSelector)] : [];
    let inspected = 0, offscreen = 0, hidden = 0, nowrapInspected = 0;
    for (const el of selected.slice(0, c.limit)) {
      if (!rendered(el)) { hidden++; continue; }
      inspected++;
      const r = el.getBoundingClientRect();
      if (r.bottom <= 0 || r.top >= innerHeight) offscreen++;
      const box = { x: round(r.x), y: round(r.y), width: round(r.width), height: round(r.height) };
      if (r.width < c.minTarget - .5 || r.height < c.minTarget - .5)
        issues.push({ type: "small-target", ...identify(el), box });
      let scrollOwner = null;
      let exposed = { left: r.left, right: r.right };
      for (let p = el.parentElement; p; p = p.parentElement) {
        const s = getComputedStyle(p), pr = p.getBoundingClientRect();
        if (s.display === "contents") continue;
        const left = pr.left + p.clientLeft, right = left + p.clientWidth;
        if (["auto", "scroll"].includes(s.overflowX) && p.scrollWidth > p.clientWidth + 1 && !["BODY", "HTML"].includes(p.tagName)) {
          scrollOwner ??= p;
          // Outer ancestors clip the scroll viewport, not its offscreen descendants.
          exposed = { left, right };
        }
        if (["hidden", "clip"].includes(s.overflowX) && (exposed.left < left - 1 || exposed.right > right + 1)) {
          issues.push({ type: "clipped-by-ancestor", ...identify(el), ancestor: identify(p), box });
          break;
        }
      }
      if (r.left < -1 || r.right > innerWidth + 1)
        issues.push({ type: scrollOwner && exposed.left >= -1 && exposed.right <= innerWidth + 1 ? "outside-scroll-window" : "outside-viewport", ...identify(el), box });
      if (!["INPUT", "TEXTAREA"].includes(el.tagName) && el.scrollWidth > el.clientWidth + 1 && ["hidden", "clip"].includes(getComputedStyle(el).overflowX))
        issues.push({ type: "clipped-control", ...identify(el), box });
    }
    for (const el of nowrap.slice(0, c.limit)) {
      if (!rendered(el)) continue;
      nowrapInspected++;
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
    if (c.expectedMobile === false && (actual.coarsePointer || actual.maxTouchPoints > 0)) mismatches.push("desktop-environment");
    if (c.expectedMode !== null && actual.mediaDark !== (c.expectedMode === "dark")) mismatches.push("color-scheme-media");
    const overflow = Math.max(actual.scrollWidth - actual.clientWidth, c.expectedWidth === null ? 0 : actual.scrollWidth - c.expectedWidth);
    if (overflow > 1) issues.push({ type: "document-horizontal-overflow", pixels: round(overflow) });
    return {
      url: location.href, requested: c, actual, environmentMatches: mismatches.length === 0, mismatches,
      counts: { controls: selected.length, inspected, hidden, offscreen, nowrap: nowrap.length, nowrapInspected },
      coverageWarnings: [
        ...([document.documentElement, document.body].some(el => ["hidden", "clip"].includes(getComputedStyle(el).overflowX))
          ? ["root/body hides horizontal overflow; inspect non-control content visually"] : []),
        ...(selected.length === 0 ? ["control selector matched no elements"] : []),
        ...(c.nowrapSelector && nowrap.length === 0 ? ["nowrap selector matched no elements"] : []),
        ...(offscreen ? ["offscreen geometry measured; scroll and verify reachability separately"] : []),
      ],
      truncated: selected.length > c.limit || nowrap.length > c.limit,
      fonts: { status: document.fonts.status, faces: [...document.fonts].map(f => ({ family: f.family, status: f.status })) },
      issues,
      limitations: ["rendered DOM geometry only; not a pass/fail verdict", "no virtualized content, iframe or shadow DOM scan",
        "clipping inspection covers selected controls only, not arbitrary text or images",
        "does not prove touch actions, occlusion, keyboard behavior, actual font use, or real-device compatibility"],
    };
  }, config);
}
