// Missive Solo: when Forward (or Reply / Reply All) is clicked, auto-pick the
// "In this conversation" choice instead of showing the chooser menu.
//
// How Missive's menu works (from the app bundle): choices are rendered as
// `span.option` nodes inside a ContextMenu component and are *selected on
// mouseup* (click on touch devices). Submenus also open on hover, so we only
// act when the user actually clicked a Forward/Reply control within the last
// few hundred ms -- never on hover alone. That covers the context menu, the
// toolbar buttons and the icon-only buttons at the bottom of each message.
// Hold Alt while clicking to get the menu as before. Keyboard shortcuts
// (f / r / a) never showed the chooser.
(() => {
  const PICK = "In this conversation";
  const ARMING = new Set(["Forward", "Reply", "Reply all", "Reply All"]);
  const WINDOW_MS = 600;
  let armedUntil = 0;
  let bypass = false;
  const log = (...a) => console.debug("[missive-solo]", ...a);

  const labelOf = (el) =>
    (el.getAttribute("data-tooltip-content") || el.getAttribute("title") || el.getAttribute("aria-label") || el.textContent || "").trim();

  // The per-message footer buttons (renderMessageQuickActions in the bundle)
  // are icon-only unless "show action labels" is on: a div.button-macos
  // holding an <i class="missive-icon missive-icon-<icon>">. Forward is
  // ic_arrow, Reply ic_outline_reply, Reply All ic_outline_reply-all. Their
  // click opens the same chooser menu via contextMenu:open. (Resend also has
  // an "In this conversation" option, so match icons, never the whole bar.)
  const FOOTER_ICONS = ".missive-icon-ic_arrow, .missive-icon-ic_outline_reply, .missive-icon-ic_outline_reply-all";
  const footerLabel = (el) => {
    if (!el.matches(".missive-message-actions .button-macos")) return "";
    const icon = el.querySelector(FOOTER_ICONS);
    return icon ? "footer:" + icon.className.match(/missive-icon-(\S+)/)[1] : "";
  };

  // the Forward/Reply control under a mouseup, if any (menu option, toolbar
  // button or message footer button)
  function armingControl(target) {
    let el = target instanceof Element ? target : target?.parentElement;
    for (let i = 0; el && i < 6; i++, el = el.parentElement) {
      if (ARMING.has(labelOf(el)) || footerLabel(el)) return el;
    }
    return null;
  }

  function findChoice(root) {
    if (!(root instanceof Element)) return null;
    if (root.matches(".option") && root.textContent.trim() === PICK) return root;
    for (const o of root.querySelectorAll(".option")) if (o.textContent.trim() === PICK) return o;
    return null;
  }

  function choose(opt, how) {
    armedUntil = 0;
    if (bypass) { log("alt held; leaving the menu open"); return; }
    // mouseup selects on desktop (click is a no-op there); click selects on touch
    for (const type of ["mouseup", "click"]) {
      opt.dispatchEvent(new MouseEvent(type, { bubbles: true, cancelable: true, button: 0, view: window }));
    }
    log(`picked "${PICK}" (${how})`);
  }

  // capture phase: runs before Missive's own mouseup handler
  document.addEventListener("mouseup", (e) => {
    if (e.button !== 0) return;
    const control = armingControl(e.target);
    if (!control) return;
    bypass = e.altKey;
    armedUntil = Date.now() + WINDOW_MS;
    log("armed by", JSON.stringify(labelOf(control) || footerLabel(control)), control.tagName, control.className);
    // submenu already open (hover opened it before the click): pick now and
    // swallow the click so Missive doesn't treat it as "close menu"
    const existing = findChoice(document.body);
    if (existing && !bypass) {
      e.stopPropagation();
      e.preventDefault();
      choose(existing, "already-open submenu");
    }
  }, true);

  new MutationObserver((muts) => {
    if (Date.now() > armedUntil) return;
    for (const m of muts) {
      for (const n of m.addedNodes) {
        const opt = findChoice(n);
        if (opt) { choose(opt, "menu opened"); return; }
      }
    }
  }).observe(document.documentElement, { childList: true, subtree: true });

  log("loaded");
})();
