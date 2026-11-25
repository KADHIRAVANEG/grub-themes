/* Gorgeous GRUB — vanilla site logic */

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

const state = { themes: [], filter: "all", query: "" };

async function loadThemes() {
  if (Array.isArray(window.GRUB_THEME_CATALOG)) {
    state.themes = window.GRUB_THEME_CATALOG;
    state.themes.forEach(hydrateThemeConfig);
    return;
  }
  const res = await fetch("./themes.json", { cache: "no-cache" });
  if (!res.ok) throw new Error(`themes.json returned HTTP ${res.status}`);
  state.themes = await res.json();
  await Promise.all(state.themes.map(async (theme) => {
    const themeRes = await fetch(`./${encodeURIComponent(theme.slug)}/theme.txt`, { cache: "no-cache" });
    if (!themeRes.ok) throw new Error(`${theme.slug}/theme.txt returned HTTP ${themeRes.status}`);
    theme.themeText = await themeRes.text();
    hydrateThemeConfig(theme);
  }));
}

function parseComponent(source, component, required = false) {
  const block = source.match(new RegExp(`\\+\\s*${component}\\s*\\{([\\s\\S]*?)\\}`));
  if (!block) {
    if (required) throw new Error(`theme.txt has no ${component} component`);
    return null;
  }
  const values = {};
  for (const line of block[1].split("\n")) {
    const property = line.match(/^\s*([a-z_]+)\s*=\s*(?:"([^"]*)"|([^\s#]+))/);
    if (property) values[property[1]] = property[2] ?? property[3];
  }
  return values;
}

function parseComponents(source, component) {
  const blocks = [];
  const expression = new RegExp(`\\+\\s*${component}\\s*\\{([\\s\\S]*?)\\}`, "g");
  for (const match of source.matchAll(expression)) {
    const values = {};
    for (const line of match[1].split("\n")) {
      const property = line.match(/^\s*([a-z_]+)\s*=\s*(?:"([^"]*)"|([^\s#]+))/);
      if (property) values[property[1]] = property[2] ?? property[3];
    }
    blocks.push(values);
  }
  return blocks;
}

function hydrateThemeConfig(theme) {
  const desktop = theme.themeText.match(/^\s*desktop-image:\s*"([^"]+)"/m);
  if (!desktop) throw new Error(`${theme.slug}/theme.txt has no desktop-image`);
  theme.desktopImage = desktop[1];
  theme.desktopScaleMethod = theme.themeText.match(/^\s*desktop-image-scale-method:\s*"?([^"\s]+)"?/m)?.[1] || "stretch";
  theme.bootMenus = parseComponents(theme.themeText, "boot_menu");
  if (!theme.bootMenus.length) throw new Error(`${theme.slug}/theme.txt has no boot_menu component`);
  theme.bootMenu = theme.bootMenus[0];
  theme.progressBar = parseComponent(theme.themeText, "progress_bar");
  theme.labels = parseComponents(theme.themeText, "label");
  theme.images = parseComponents(theme.themeText, "image");
}

function grubCoordinate(value, total, fallback = 0) {
  if (!value) return fallback;
  return value.endsWith("%") ? Number.parseFloat(value) * total / 100 : Number.parseFloat(value);
}

function styledBoxHtml(theme, pattern, x, y, width, height, edge = 8) {
  if (!pattern) return "";
  const asset = (part) => `./${encodeURIComponent(theme.slug)}/${pattern.replace("*", part).split("/").map(encodeURIComponent).join("/")}`;
  const middleWidth = Math.max(0, width - edge * 2);
  const middleHeight = Math.max(0, height - edge * 2);
  const image = (part, px, py, pw, ph) => `<image href="${asset(part)}" x="${px}" y="${py}" width="${pw}" height="${ph}" preserveAspectRatio="none"/>`;
  return image("nw", x, y, edge, edge) + image("n", x + edge, y, middleWidth, edge) + image("ne", x + width - edge, y, edge, edge)
    + image("w", x, y + edge, edge, middleHeight) + image("c", x + edge, y + edge, middleWidth, middleHeight) + image("e", x + width - edge, y + edge, edge, middleHeight)
    + image("sw", x, y + height - edge, edge, edge) + image("s", x + edge, y + height - edge, middleWidth, edge) + image("se", x + width - edge, y + height - edge, edge, edge);
}

function actualPreviewHtml(theme, lazy = false, overrideSelected = null, progressRatio = 0.62, scope = "grid") {
  const selectedIndex = overrideSelected !== null ? overrideSelected : (theme.menu.selected || 0);
  const selected = Math.max(0, Math.min(selectedIndex, theme.menu.entries.length - 1));
  const clipId = `menu-${scope}-${theme.slug.replace(/[^a-zA-Z0-9_-]/g, "")}`;
  const isInteractive = scope === "sim";
  const menuLayers = (theme.bootMenus || [theme.bootMenu]).map((menu, layerIndex) => {
    const left = grubCoordinate(menu.left, 1920);
    const top = grubCoordinate(menu.top, 1080);
    const width = grubCoordinate(menu.width, 1920, 960);
    const height = grubCoordinate(menu.height, 1080, 540);
    const itemHeight = Number.parseFloat(menu.item_height) || 52;
    const spacing = Number.parseFloat(menu.item_spacing) || 0;
    const padding = Number.parseFloat(menu.item_padding) || 0;
    const configuredFont = menu.item_font || "Unifont Regular 16";
    const fontSize = Number.parseFloat(configuredFont.match(/(\d+)(?!.*\d)/)?.[1]) || 16;
    const fontFamily = configuredFont.replace(/\s+(?:Regular|Bold|Italic)?\s*\d+$/i, "");
    const normalColor = menu.item_color || "#ffffff";
    const selectedColor = menu.selected_item_color === "inherit" ? normalColor : (menu.selected_item_color || normalColor);
    const isSingleSlot = height <= (itemHeight + spacing) * 1.5;
    const entriesToRender = isSingleSlot
      ? [{ entry: theme.menu.entries[selected] || theme.menu.entries[0], index: selected, y: top }]
      : theme.menu.entries.map((entry, index) => ({ entry, index, y: top + index * (itemHeight + spacing) }))
          .filter(item => item.y < top + height);

    const rows = entriesToRender.map(({ entry, index, y }) => {
      const rowStyle = index === selected ? menu.selected_item_pixmap_style : menu.item_pixmap_style;
      const rowBox = styledBoxHtml(theme, rowStyle, left, y, width, itemHeight);
      const hitTarget = isInteractive
        ? `<rect data-entry-index="${index}" x="${left}" y="${y}" width="${width}" height="${itemHeight}" fill="transparent" style="cursor:pointer"/>`
        : "";
      return `${rowBox}<text x="${left + padding}" y="${y + itemHeight * 0.67}" fill="${escapeHtml(index === selected ? selectedColor : normalColor)}" font-family="${escapeHtml(fontFamily)}, monospace" font-size="${fontSize}">${escapeHtml(entry)}</text>${hitTarget}`;
    }).join("");
    const frame = styledBoxHtml(theme, menu.menu_pixmap_style, left, top, width, height);
    return `${frame}<g clip-path="url(#${clipId}-${layerIndex})">${rows}</g><clipPath id="${clipId}-${layerIndex}"><rect x="${left}" y="${top}" width="${width}" height="${height}"/></clipPath>`;
  }).join("");
  const imageLayers = (theme.images || []).map((component) => {
    if (!component.file) return "";
    const x = grubCoordinate(component.left, 1920);
    const y = grubCoordinate(component.top, 1080);
    const path = component.file.split("/").map(encodeURIComponent).join("/");
    return `<image href="./${encodeURIComponent(theme.slug)}/${path}" x="${x}" y="${y}"/>`;
  }).join("");
  const labels = (theme.labels || []).map((label) => {
    const labelLeft = grubCoordinate(label.left, 1920);
    const labelTop = grubCoordinate(label.top, 1080);
    const labelWidth = grubCoordinate(label.width, 1920);
    const labelFont = label.font || "Unifont Regular 16";
    const labelSize = Number.parseFloat(labelFont.match(/(\d+)(?!.*\d)/)?.[1]) || 16;
    const labelFamily = labelFont.replace(/\s+(?:Regular|Bold|Italic)?\s*\d+$/i, "");
    const anchor = label.align === "center" ? "middle" : label.align === "right" ? "end" : "start";
    const labelX = label.align === "center" ? labelLeft + labelWidth / 2 : label.align === "right" ? labelLeft + labelWidth : labelLeft;
    return `<text x="${labelX}" y="${labelTop + labelSize}" text-anchor="${anchor}" fill="${escapeHtml(label.color || "#ffffff")}" font-family="${escapeHtml(labelFamily)}, monospace" font-size="${labelSize}">${escapeHtml(label.text || "")}</text>`;
  }).join("");
  let progress = "";
  if (theme.progressBar) {
    const bar = theme.progressBar;
    const barLeft = grubCoordinate(bar.left, 1920);
    const barWidth = grubCoordinate(bar.width, 1920, 500);
    const barHeight = grubCoordinate(bar.height, 1080, 4);
    const barTop = bar.top ? grubCoordinate(bar.top, 1080) : 1080 - grubCoordinate(bar.bottom, 1080) - barHeight;
    const currentWidth = Math.max(0, Math.min(barWidth, barWidth * progressRatio));
    progress = `<rect x="${barLeft}" y="${barTop}" width="${barWidth}" height="${barHeight}" fill="${escapeHtml(bar.bg_color || "#000000")}" stroke="${escapeHtml(bar.border_color || "#ffffff")}" stroke-width="1"/><rect class="sim-progress-bar-fill" data-max-width="${barWidth}" x="${barLeft}" y="${barTop}" width="${currentWidth}" height="${barHeight}" fill="${escapeHtml(bar.fg_color || "#ffffff")}"/>`;
  }
  const desktopImage = theme.desktopImage.split("/").map(encodeURIComponent).join("/");
  return `<div class="actual-screen">
    <img class="actual-preview scale-${escapeHtml(theme.desktopScaleMethod)}" src="./${encodeURIComponent(theme.slug)}/${desktopImage}" alt="${escapeHtml(theme.title)} GRUB boot screen preview" decoding="async"${lazy ? ' loading="lazy"' : ""}>
    <svg class="actual-menu" viewBox="0 0 1920 1080" aria-hidden="true">
      ${imageLayers}${menuLayers}${labels}${progress}
    </svg>
  </div>`;
}

function uniqueTags(themes) {
  const set = new Set();
  themes.forEach((t) => (t.tags || []).forEach((tag) => set.add(tag)));
  return Array.from(set).sort();
}

function renderTags() {
  const tags = ["all", ...uniqueTags(state.themes)];
  const container = $("#tags");
  container.innerHTML = tags
    .map((t) => `<button class="tag${t === state.filter ? " active" : ""}" data-tag="${escapeHtml(t)}">${t === "all" ? "all" : "#" + escapeHtml(t)}</button>`)
    .join("");
  $$(".tag", container).forEach((el) =>
    el.addEventListener("click", () => { state.filter = el.dataset.tag; renderTags(); renderGrid(); })
  );
}

function filtered() {
  const q = state.query.trim().toLowerCase();
  return state.themes.filter((t) => {
    const matchesTag = state.filter === "all" || (t.tags || []).includes(state.filter);
    const matchesQuery = !q || t.title.toLowerCase().includes(q) || t.tagline.toLowerCase().includes(q) || (t.tags || []).some((tag) => tag.includes(q));
    return matchesTag && matchesQuery;
  });
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

function statusBadge(theme) {
  if (theme.status === "maintenance") {
    return `<span class="badge badge-maintenance">🔧 Maintenance</span>`;
  }
  return `<span class="badge badge-working">✅ Working</span>`;
}

function renderGrid() {
  const items = filtered();
  const grid = $("#theme-grid");
  if (!items.length) {
    grid.innerHTML = `<div class="empty-state"><span>No configs match current filter or query.</span><button type="button" class="btn btn-ghost btn-sm" id="btn-clear-filters">Clear filters</button></div>`;
    const clearBtn = $("#btn-clear-filters", grid);
    if (clearBtn) {
      clearBtn.addEventListener("click", () => {
        state.filter = "all";
        state.query = "";
        const search = $("#search");
        if (search) search.value = "";
        renderTags();
        renderGrid();
      });
    }
    return;
  }
  grid.innerHTML = items.map((t) => {
    const num = String(state.themes.indexOf(t) + 1).padStart(2, "0");
    const escapedSlug = escapeHtml(t.slug);
    return `
      <article class="card${t.status === "maintenance" ? " card-maintenance" : ""}" data-slug="${escapedSlug}" tabindex="0" role="button" aria-label="Preview ${escapeHtml(t.title)} theme">
        <div class="card-head">
          <span>${num} // <b>${escapeHtml(t.title.toUpperCase())}</b></span>
          ${t.status === "maintenance" ? statusBadge(t) : ""}
        </div>
        <div class="card-preview">${actualPreviewHtml(t, true, null, 0.62, "grid")}</div>
        <div class="card-meta">
          <span class="name">${escapeHtml(t.tagline)}</span>
          <span class="cmd">sudo ./install.sh ${escapedSlug}</span>
        </div>
      </article>`;
  }).join("");
  $$(".card", grid).forEach((card) => {
    card.addEventListener("click", () => openModal(card.dataset.slug));
    card.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        openModal(card.dataset.slug);
      }
    });
  });
}

const simulatorState = {
  theme: null,
  selected: 0,
  timerSeconds: 10,
  timerInterval: null,
  isBooted: false
};

function mountSimulator() {
  const modal = $("#theme-modal");
  const previewContainer = $("[data-field=preview]", modal);
  if (!simulatorState.theme) return;

  const ratio = Math.max(0, Math.min(1, simulatorState.timerSeconds / 10));
  const html = actualPreviewHtml(simulatorState.theme, false, simulatorState.selected, ratio, "sim");

  previewContainer.innerHTML = `
    <div class="actual-preview-wrap simulator-wrap" id="sim-viewport" tabindex="0">
      <button type="button" class="sim-exit-fullscreen-btn" id="btn-exit-sim" aria-label="Exit Fullscreen">✕ Exit Fullscreen (Esc)</button>
      <div id="sim-screen-container">
        ${html}
      </div>
      <div class="boot-screen-overlay" id="sim-boot-overlay" style="display:none;">
        <div class="boot-terminal">
          <p class="boot-line" id="boot-terminal-entry">Booting '${escapeHtml(simulatorState.theme.menu.entries[simulatorState.selected] || "Linux")}'...</p>
          <p class="boot-line">Loading Linux linux...</p>
          <p class="boot-line">Loading initial ramdisk...</p>
          <p class="boot-line boot-cursor">_</p>
          <button type="button" class="btn btn-ghost btn-sm" id="btn-reboot-sim" style="margin-top:20px;">↺ Reboot Test Drive</button>
        </div>
      </div>
    </div>
  `;

  const rebootBtn = $("#btn-reboot-sim", previewContainer);
  if (rebootBtn) {
    rebootBtn.addEventListener("click", () => {
      simulatorState.isBooted = false;
      simulatorState.timerSeconds = 10;
      const overlay = $("#sim-boot-overlay", previewContainer);
      if (overlay) overlay.style.display = "none";
      updateSimulatorScreen();
      startSimulatorTimer();
    });
  }

  const exitBtn = $("#btn-exit-sim", previewContainer);
  if (exitBtn) {
    exitBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      exitFullscreenSimulator();
    });
  }

  const screenContainer = $("#sim-screen-container", previewContainer);
  if (screenContainer) {
    screenContainer.addEventListener("click", (e) => {
      const target = e.target.closest("[data-entry-index]");
      if (!target || simulatorState.isBooted) return;
      const nextIndex = Number.parseInt(target.dataset.entryIndex, 10);
      if (Number.isNaN(nextIndex)) return;
      stopSimulatorTimer();
      simulatorState.selected = nextIndex;
      updateSimulatorScreen();
    });
  }
}

function updateSimulatorScreen() {
  const screenContainer = document.getElementById("sim-screen-container");
  if (!screenContainer || !simulatorState.theme) return;
  const ratio = Math.max(0, Math.min(1, simulatorState.timerSeconds / 10));
  screenContainer.innerHTML = actualPreviewHtml(simulatorState.theme, false, simulatorState.selected, ratio, "sim");
}

function updateSimulatorTimerTick() {
  const viewport = document.getElementById("sim-viewport");
  if (!viewport || !simulatorState.theme || simulatorState.isBooted) return;

  const bar = viewport.querySelector(".sim-progress-bar-fill");
  if (bar) {
    const maxWidth = Number.parseFloat(bar.dataset.maxWidth) || 0;
    const ratio = Math.max(0, Math.min(1, simulatorState.timerSeconds / 10));
    bar.setAttribute("width", String(Math.max(0, Math.min(maxWidth, maxWidth * ratio))));
  }
}

function startSimulatorTimer() {
  stopSimulatorTimer();
  simulatorState.timerInterval = setInterval(() => {
    if (simulatorState.isBooted) return;
    if (simulatorState.timerSeconds > 0) {
      simulatorState.timerSeconds = Math.max(0, simulatorState.timerSeconds - 0.2);
      updateSimulatorTimerTick();
    } else {
      triggerSimulatorBoot();
    }
  }, 200);
}

function stopSimulatorTimer() {
  if (simulatorState.timerInterval) {
    clearInterval(simulatorState.timerInterval);
    simulatorState.timerInterval = null;
  }
}

function triggerSimulatorBoot() {
  stopSimulatorTimer();
  simulatorState.isBooted = true;
  const overlay = document.getElementById("sim-boot-overlay");
  const entryText = document.getElementById("boot-terminal-entry");
  if (overlay && simulatorState.theme) {
    const entryName = simulatorState.theme.menu.entries[simulatorState.selected] || "Linux";
    if (entryText) entryText.textContent = `Booting '${entryName}'...`;
    overlay.style.display = "flex";
  }
}

function isSimulatorFullscreen() {
  const el = document.getElementById("sim-viewport");
  return Boolean(
    document.fullscreenElement ||
    document.webkitFullscreenElement ||
    document.mozFullScreenElement ||
    document.msFullscreenElement ||
    (el && el.classList.contains("is-fullscreen-sim"))
  );
}

function updateFullscreenButtonState() {
  const btn = document.getElementById("btn-fullscreen-drive");
  if (!btn) return;
  const isFs = isSimulatorFullscreen();
  if (isFs) {
    btn.textContent = "✕ Exit Fullscreen (F)";
    btn.classList.add("btn-active-fs");
  } else {
    btn.textContent = "⛶ Fullscreen (F)";
    btn.classList.remove("btn-active-fs");
  }
}

function enterFullscreenSimulator() {
  const el = document.getElementById("sim-viewport");
  if (!el) return;

  const rfs = el.requestFullscreen ||
              el.webkitRequestFullscreen ||
              el.mozRequestFullScreen ||
              el.msRequestFullscreen;

  if (rfs) {
    try {
      const p = rfs.call(el);
      if (p && typeof p.catch === "function") {
        p.catch(() => {
          el.classList.add("is-fullscreen-sim");
          document.body.classList.add("sim-fullscreen-active");
          updateFullscreenButtonState();
        });
      }
    } catch {
      el.classList.add("is-fullscreen-sim");
      document.body.classList.add("sim-fullscreen-active");
      updateFullscreenButtonState();
    }
  } else {
    el.classList.add("is-fullscreen-sim");
    document.body.classList.add("sim-fullscreen-active");
    updateFullscreenButtonState();
  }
  updateFullscreenButtonState();
  el.focus();
}

function exitFullscreenSimulator() {
  const el = document.getElementById("sim-viewport");
  if (el) el.classList.remove("is-fullscreen-sim");
  document.body.classList.remove("sim-fullscreen-active");

  if (document.fullscreenElement || document.webkitFullscreenElement || document.mozFullScreenElement || document.msFullscreenElement) {
    const efs = document.exitFullscreen ||
                document.webkitExitFullscreen ||
                document.mozCancelFullScreen ||
                document.msExitFullscreen;
    if (efs) {
      try {
        const p = efs.call(document);
        if (p && typeof p.catch === "function") p.catch(() => {});
      } catch {}
    }
  }
  updateFullscreenButtonState();
}

function toggleFullscreenSimulator() {
  if (isSimulatorFullscreen()) {
    exitFullscreenSimulator();
  } else {
    enterFullscreenSimulator();
  }
}

function handleSimulatorKey(e) {
  const modal = $("#theme-modal");
  if (!modal || (!modal.open && !modal.hasAttribute("open"))) return;
  if (!simulatorState.theme) return;

  const entriesCount = simulatorState.theme.menu.entries.length;

  if (e.key === "f" || e.key === "F") {
    if (e.target.tagName !== "INPUT" && e.target.tagName !== "TEXTAREA") {
      e.preventDefault();
      toggleFullscreenSimulator();
      return;
    }
  }

  if (e.key === "Escape") {
    if (isSimulatorFullscreen()) {
      e.preventDefault();
      exitFullscreenSimulator();
      return;
    }
  }

  if (simulatorState.isBooted) return;

  if (e.key === "ArrowDown" || e.key === "ArrowRight") {
    e.preventDefault();
    stopSimulatorTimer();
    simulatorState.selected = (simulatorState.selected + 1) % entriesCount;
    updateSimulatorScreen();
  } else if (e.key === "ArrowUp" || e.key === "ArrowLeft") {
    e.preventDefault();
    stopSimulatorTimer();
    simulatorState.selected = (simulatorState.selected - 1 + entriesCount) % entriesCount;
    updateSimulatorScreen();
  } else if (e.key === "Enter") {
    e.preventDefault();
    triggerSimulatorBoot();
  }
}

async function openModal(slug) {
  const theme = state.themes.find((t) => t.slug === slug);
  if (!theme) return;
  const modal = $("#theme-modal");
  $("[data-field=title]", modal).innerHTML = `${escapeHtml(theme.title)} ${statusBadge(theme)}`;
  $("[data-field=layout]", modal).textContent = `${theme.layoutLabel} · ${theme.font}`;
  $("[data-field=tagline]", modal).textContent = theme.tagline;
  $("[data-field=cmd]", modal).textContent = `sudo ./install.sh ${theme.slug}`;

  const refindEl = $("#modal-refind-note", modal);
  if (refindEl) {
    if (theme.refind) {
      refindEl.style.display = "block";
      refindEl.innerHTML = `💡 <b>Layout &amp; Navigation:</b> In standard GRUB2, menus operate vertically (<code>↑</code> / <code>↓</code>). For a native horizontal icon dock with left/right navigation (<code>←</code> / <code>→</code>), install the companion rEFInd theme: <code>sudo ./install.sh -r ${escapeHtml(theme.slug)}</code>`;
    } else {
      refindEl.style.display = "none";
      refindEl.innerHTML = "";
    }
  }

  simulatorState.theme = theme;
  simulatorState.selected = theme.menu.selected || 0;
  simulatorState.timerSeconds = 10;
  simulatorState.isBooted = false;

  mountSimulator();
  startSimulatorTimer();
  updateFullscreenButtonState();

  const txtEl = $("[data-field=theme-txt]", modal);
  txtEl.textContent = theme.themeText || "(theme.txt not found)";
  if (typeof modal.showModal === "function") modal.showModal();
  else modal.setAttribute("open", "");
}

function wireModal() {
  const modal = $("#theme-modal");
  modal.addEventListener("click", (e) => {
    if (e.target === modal || e.target.matches("[data-close]")) {
      exitFullscreenSimulator();
      stopSimulatorTimer();
      if (typeof modal.close === "function") modal.close();
      else modal.removeAttribute("open");
    }
  });
  modal.addEventListener("cancel", (e) => {
    if (isSimulatorFullscreen()) {
      e.preventDefault();
      exitFullscreenSimulator();
    }
  });
  modal.addEventListener("close", () => {
    exitFullscreenSimulator();
    stopSimulatorTimer();
  });
  const driveBtn = $("#btn-fullscreen-drive");
  if (driveBtn) driveBtn.addEventListener("click", toggleFullscreenSimulator);
  const copyBtn = $("#btn-copy-cmd");
  if (copyBtn) {
    copyBtn.addEventListener("click", async () => {
      const cmdText = $("[data-field=cmd]", modal)?.textContent || "";
      if (!cmdText) return;
      try {
        await navigator.clipboard.writeText(cmdText);
      } catch {
        const tmp = document.createElement("textarea");
        tmp.value = cmdText;
        tmp.setAttribute("readonly", "");
        tmp.style.position = "fixed";
        tmp.style.opacity = "0";
        document.body.appendChild(tmp);
        tmp.select();
        document.execCommand("copy");
        tmp.remove();
      }
      copyBtn.textContent = "✓ Copied";
      setTimeout(() => { copyBtn.textContent = "Copy"; }, 1400);
    });
  }
  window.addEventListener("keydown", handleSimulatorKey);
  document.addEventListener("fullscreenchange", updateFullscreenButtonState);
  document.addEventListener("webkitfullscreenchange", () => {
    const el = document.getElementById("sim-viewport");
    if (el && document.webkitFullscreenElement === el && !document.fullscreenElement) {
      el.classList.add("is-fullscreen-sim");
    } else if (el && !document.webkitFullscreenElement && !document.fullscreenElement) {
      el.classList.remove("is-fullscreen-sim");
    }
    updateFullscreenButtonState();
  });
  document.addEventListener("mozfullscreenchange", updateFullscreenButtonState);
  document.addEventListener("MSFullscreenChange", updateFullscreenButtonState);
}

function wireSearch() {
  const search = $("#search");
  search.addEventListener("input", (e) => { state.query = e.target.value; renderGrid(); });
  search.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && search.value) {
      e.preventDefault();
      search.value = "";
      state.query = "";
      renderGrid();
    }
  });
  window.addEventListener("keydown", (e) => {
    if (e.key !== "/" || e.ctrlKey || e.metaKey || e.altKey) return;
    const modal = $("#theme-modal");
    if (modal && (modal.open || modal.hasAttribute("open"))) return;
    const tag = e.target?.tagName;
    if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;
    e.preventDefault();
    search.focus();
  });
}

function updateCtaCount() {
  $("#cta-count").textContent = `browse ${state.themes.length}`;
}

(async function init() {
  wireModal();
  wireSearch();
  try {
    await loadThemes();
    renderTags();
    renderGrid();
    updateCtaCount();
  } catch (error) {
    console.error(error);
    $("#theme-grid").innerHTML = `<p class="loading">Could not load the theme catalog. Serve this directory over HTTP and try again.</p>`;
  }
})();
