/* Gorgeous GRUB — vanilla site logic */

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

const state = {
  themes: [],
  filter: "all",
  query: "",
};

async function loadThemes() {
  const res = await fetch("./themes.json", { cache: "no-cache" });
  state.themes = await res.json();
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
    .map(
      (t) =>
        `<button class="tag${t === state.filter ? " active" : ""}" data-tag="${t}">${
          t === "all" ? "all" : "#" + t
        }</button>`
    )
    .join("");
  $$(".tag", container).forEach((el) =>
    el.addEventListener("click", () => {
      state.filter = el.dataset.tag;
      renderTags();
      renderGrid();
    })
  );
}

function filtered() {
  const q = state.query.trim().toLowerCase();
  return state.themes.filter((t) => {
    const matchesTag =
      state.filter === "all" || (t.tags || []).includes(state.filter);
    const matchesQuery =
      !q ||
      t.title.toLowerCase().includes(q) ||
      t.tagline.toLowerCase().includes(q) ||
      (t.tags || []).some((tag) => tag.includes(q));
    return matchesTag && matchesQuery;
  });
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[c]);
}

function entriesHtml(m, cls = "") {
  return m.entries
    .map((e, i) => `<li class="${cls}${i === m.selected ? " sel" : ""}">${escapeHtml(e)}</li>`)
    .join("");
}

function mockMiku(t) {
  const m = t.menu;
  return `
    <div class="grub g-miku">
      <div class="g-miku-frame">
        <div class="g-miku-corners"><i></i><i></i><i></i><i></i></div>
        <div class="g-miku-title">${escapeHtml(m.title)}</div>
        <ul class="g-miku-list">${entriesHtml(m)}</ul>
        <div class="g-miku-bar"><span></span></div>
        <div class="g-miku-meta"><span>SYS::OK</span><span>${escapeHtml(m.timeout)}</span></div>
      </div>
    </div>`;
}

function mockPenguin(t) {
  const m = t.menu;
  const tux = [
    "   .--.   ",
    "  |o_o |  ",
    "  |:_/ |  ",
    " //   \\ \\ ",
    "(|     | )",
    "/'\\_   _/`\\",
    "\\___)=(___/",
  ].join("\n");
  return `
    <div class="grub g-penguin">
      <div class="g-pen-bar"><span class="d r"></span><span class="d y"></span><span class="d g"></span><span class="t">${escapeHtml(m.title)}</span></div>
      <div class="g-pen-body">
        <pre class="g-pen-tux">${tux}</pre>
        <div class="g-pen-menu">
          <div class="g-pen-prompt">$ select-os --timeout=${escapeHtml(m.timeout)}</div>
          <ul>${entriesHtml(m)}</ul>
          <div class="g-pen-hint">↑/↓ move · ↵ boot</div>
        </div>
      </div>
    </div>`;
}

function mockNes(t) {
  const m = t.menu;
  const items = m.entries
    .map((e, i) => `<li class="${i === m.selected ? "sel" : ""}"><span>${i === m.selected ? "►" : " "}</span>${escapeHtml(e)}</li>`)
    .join("");
  return `
    <div class="grub g-nes">
      <div class="g-nes-screen">
        <div class="g-nes-logo">GRUB-NES</div>
        <div class="g-nes-title">${escapeHtml(m.title)}</div>
        <ul>${items}</ul>
        <div class="g-nes-blink">${escapeHtml(m.timeout)}</div>
      </div>
    </div>`;
}

function mockNimbus(t) {
  const m = t.menu;
  const icons = ["◐", "◑", "◒", "◓"];
  const items = m.entries
    .map(
      (e, i) => `
      <div class="g-nim-app ${i === m.selected ? "sel" : ""}">
        <div class="g-nim-icon">${icons[i % icons.length]}</div>
        <div class="g-nim-label">${escapeHtml(e)}</div>
      </div>`
    )
    .join("");
  return `
    <div class="grub g-nimbus">
      <div class="g-nim-top">${escapeHtml(m.title)} · ${escapeHtml(m.timeout)}</div>
      <div class="g-nim-dock">${items}</div>
    </div>`;
}

function mockStreet(t) {
  const m = t.menu;
  return `
    <div class="grub g-street">
      <div class="g-st-glitch">${escapeHtml(m.title)}</div>
      <ul class="g-st-list">${entriesHtml(m)}</ul>
      <div class="g-st-foot">
        <span class="g-st-tag">NET//OK</span>
        <span class="g-st-tick">${escapeHtml(m.timeout)}</span>
      </div>
    </div>`;
}

function mockGas(t) {
  const m = t.menu;
  const items = m.entries
    .map(
      (e, i) => `
      <div class="g-gas-cell ${i === m.selected ? "sel" : ""}">
        <div class="g-gas-num">0${i + 1}</div>
        <div class="g-gas-name">${escapeHtml(e)}</div>
        <div class="g-gas-bar"><span style="width:${20 + i * 20}%"></span></div>
      </div>`
    )
    .join("");
  return `
    <div class="grub g-gas">
      <div class="g-gas-head"><span>${escapeHtml(m.title)}</span><span class="g-gas-time">${escapeHtml(m.timeout)}</span></div>
      <div class="g-gas-row">${items}</div>
    </div>`;
}

function mockBmw(t) {
  const m = t.menu;
  const items = m.entries.map((e, i) => `
    <div class="g-bmw-row ${i === m.selected ? "sel" : ""}">
      <div class="g-bmw-gear">G${i + 1}</div>
      <div class="g-bmw-name">${escapeHtml(e)}</div>
      <div class="g-bmw-rpm"><span style="width:${30 + i * 18}%"></span></div>
      <div class="g-bmw-kmh">${(80 + i * 40)}<small>km/h</small></div>
    </div>`).join("");
  return `
    <div class="grub g-bmw">
      <div class="g-bmw-top">
        <span class="g-bmw-badge">M</span>
        <span class="g-bmw-title">${escapeHtml(m.title)}</span>
        <span class="g-bmw-time">${escapeHtml(m.timeout)}</span>
      </div>
      <div class="g-bmw-grid">${items}</div>
      <div class="g-bmw-hud"><span>ABS</span><span>DSC</span><span>SPORT+</span><span>● REC</span></div>
    </div>`;
}

function mockCelebrate(t) {
  const m = t.menu;
  const hats = ["⌬", "★", "✦", "☠", "♔"];
  const items = m.entries.map((e, i) => `
    <li class="${i === m.selected ? "sel" : ""}">
      <span class="g-cel-hat">${hats[i % hats.length]}</span>
      <span class="g-cel-bottle"></span>
      <span class="g-cel-name">${escapeHtml(e)}</span>
    </li>`).join("");
  return `
    <div class="grub g-celebrate">
      <ul class="g-cel-list">${items}</ul>
      <div class="g-cel-title">${escapeHtml(m.title)}</div>
      <div class="g-cel-sub">— ${escapeHtml(m.timeout)} —</div>
    </div>`;
}

function mockBen(t) {
  const m = t.menu;
  const items = m.entries.map((e, i) => {
    const angle = (360 / m.entries.length) * i - 90;
    return `<div class="g-ben-slot ${i === m.selected ? "sel" : ""}" style="transform:rotate(${angle}deg) translate(110px) rotate(${-angle}deg)">${escapeHtml(e.split(" · ")[0])}</div>`;
  }).join("");
  return `
    <div class="grub g-ben">
      <div class="g-ben-dial">
        <div class="g-ben-core">⏣</div>
        ${items}
      </div>
      <div class="g-ben-foot">
        <span>${escapeHtml(m.title)}</span>
        <span class="g-ben-timer">${escapeHtml(m.timeout)}</span>
      </div>
    </div>`;
}

function mockNoir(t) {
  const m = t.menu;
  const items = m.entries.map((e, i) => `
    <li class="${i === m.selected ? "sel" : ""}">
      <span class="g-noir-num">№ 0${i + 1}</span>
      <span class="g-noir-text">${escapeHtml(e)}</span>
    </li>`).join("");
  return `
    <div class="grub g-noir">
      <div class="g-noir-rain"></div>
      <div class="g-noir-chapter">${escapeHtml(m.title)}</div>
      <ul class="g-noir-list">${items}</ul>
      <div class="g-noir-foot">
        <span class="g-noir-stamp">CONFIDENTIAL</span>
        <span>${escapeHtml(m.timeout)}</span>
      </div>
    </div>`;
}


const mocks = { miku: mockMiku, penguin: mockPenguin, nes: mockNes, nimbus: mockNimbus, street: mockStreet, gas: mockGas, bmw: mockBmw, celebrate: mockCelebrate, ben: mockBen, noir: mockNoir };

function grubMockHtml(theme) {
  const fn = mocks[theme.layout] || mockMiku;
  return fn(theme);
}


function renderGrid() {
  const items = filtered();
  const grid = $("#theme-grid");
  if (!items.length) {
    grid.innerHTML = `<p class="loading">No configs match. Try clearing the filter.</p>`;
    return;
  }
  grid.innerHTML = items
    .map((t, idx) => {
      const num = String(state.themes.indexOf(t) + 1).padStart(2, "0");
      return `
        <article class="card" data-slug="${t.slug}">
          <div class="card-bg" style="background-image:url('${t.background}')"></div>
          <p class="card-head">${num} // <b>${escapeHtml(t.title.toUpperCase())}</b></p>
          <div class="card-preview">${grubMockHtml(t)}</div>
          <div class="card-meta">
            <span class="name">${escapeHtml(t.tagline)}</span>
            <span class="cmd">sudo ./install.sh ${t.slug}</span>
          </div>
        </article>
      `;
    })
    .join("");
  $$(".card", grid).forEach((card) =>
    card.addEventListener("click", () => openModal(card.dataset.slug))
  );
}

async function openModal(slug) {
  const theme = state.themes.find((t) => t.slug === slug);
  if (!theme) return;
  const modal = $("#theme-modal");
  $("[data-field=title]", modal).textContent = theme.title;
  $("[data-field=layout]", modal).textContent = `${theme.layoutLabel} · ${theme.font}`;
  $("[data-field=tagline]", modal).textContent = theme.tagline;
  $("[data-field=cmd]", modal).textContent = `sudo ./install.sh ${theme.slug}`;
  $("[data-field=preview]", modal).innerHTML = `
    <div style="position:relative;border-radius:8px;overflow:hidden;min-height:260px;background:#000">
      <div style="position:absolute;inset:0;background-image:url('${theme.background}');background-size:cover;background-position:center;opacity:.6"></div>
      <div style="position:relative;padding:32px 22px;">${grubMockHtml(theme)}</div>
    </div>
  `;
  // attach data-slug to apply per-theme palette inside modal preview
  $("[data-field=preview]", modal).firstElementChild.dataset.slug = theme.slug;
  $("[data-field=preview]", modal).firstElementChild.classList.add("card");

  const txtEl = $("[data-field=theme-txt]", modal);
  txtEl.textContent = "Loading…";
  try {
    const res = await fetch(`./${theme.slug}/theme.txt`, { cache: "no-cache" });
    txtEl.textContent = res.ok ? await res.text() : "(theme.txt not found)";
  } catch {
    txtEl.textContent = "(theme.txt not found)";
  }
  if (typeof modal.showModal === "function") modal.showModal();
  else modal.setAttribute("open", "");
}

function wireModal() {
  const modal = $("#theme-modal");
  modal.addEventListener("click", (e) => {
    if (e.target === modal || e.target.matches("[data-close]")) modal.close();
  });
}

function wireSearch() {
  $("#search").addEventListener("input", (e) => {
    state.query = e.target.value;
    renderGrid();
  });
}

function updateCtaCount() {
  $("#cta-count").textContent = `browse ${state.themes.length}`;
}

(async function init() {
  await loadThemes();
  renderTags();
  renderGrid();
  wireModal();
  wireSearch();
  updateCtaCount();
})();
