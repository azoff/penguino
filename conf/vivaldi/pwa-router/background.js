// PWAs run as --app windows of the main Vivaldi instance, so Chromium already
// opens their out-of-scope links as tabs in the main window. This extension
// handles the two things Chromium doesn't:
//
//  1. Links *to* a PWA origin that land in a normal (tabbed) window are sent
//     into that PWA's app window instead (focus + navigate), if one is open.
//  2. A tab in a normal window that was opened only to fire a custom scheme
//     (Vimcal "v" -> zoommtg://, msteams://, tel:, …) is a dead shell once the
//     OS has the protocol; close it.
//  3. A URL handed to the running Vivaldi from outside (xdg-open from Slack,
//     Zoom, the terminal, …) is added to the *last active* window of the
//     profile, and when that is a PWA app window Chromium creates a brand new
//     normal window for it (StartupBrowserCreatorImpl::OpenTabsInBrowser).
//     Fold that lone tab into the existing normal window instead.

const PWA_ORIGINS = ["https://mail.missiveapp.com"];

// set to e.g. "http://127.0.0.1:47123/log?" to trace events to a local server
const DEBUG_LOG = "http://127.0.0.1:47123/log?";
const dbg = (...a) => {
  if (!DEBUG_LOG) return;
  const msg = a.map((x) => (typeof x === "string" ? x : JSON.stringify(x))).join(" ");
  fetch(DEBUG_LOG + encodeURIComponent(msg), { mode: "no-cors" }).catch(() => {});
  // also keep the last lines on disk (Local Extension Settings) in case the network path is blocked
  try {
    chrome.storage.local.get("log").then(({ log = [] }) => {
      log.push(new Date().toISOString().slice(11, 19) + " " + msg);
      chrome.storage.local.set({ log: log.slice(-200) });
    });
  } catch {}
};
dbg("worker start", chrome.runtime.getManifest().version);
self.addEventListener("error", (e) => dbg("worker error", String(e.message || e)));
self.addEventListener("unhandledrejection", (e) => dbg("worker rejection", String(e.reason)));

const handled = new Set();

async function windowType(windowId) {
  try {
    return (await chrome.windows.get(windowId)).type;
  } catch {
    return null;
  }
}

async function appTabFor(origin, excludeTabId) {
  const tabs = await chrome.tabs.query({ url: origin + "/*" });
  for (const t of tabs) {
    if (t.id === undefined || t.id === excludeTabId) continue;
    if ((await windowType(t.windowId)) === "app") return t;
  }
  return null;
}

async function maybeRoute(tab) {
  if (!tab || tab.id === undefined || handled.has(tab.id)) return;
  const url = tab.pendingUrl || tab.url || "";
  let origin;
  try {
    origin = new URL(url).origin;
  } catch {
    return;
  }
  if (!PWA_ORIGINS.includes(origin)) return;
  handled.add(tab.id); // onCreated and onUpdated race on the same tab
  try {
    if ((await windowType(tab.windowId)) !== "normal") return;
    const app = await appTabFor(origin, tab.id);
    if (!app) return; // app window not open: leave the link as a tab
    await chrome.tabs.update(app.id, { url, active: true });
    await chrome.windows.update(app.windowId, { focused: true });
    await chrome.tabs.remove(tab.id);
    return;
  } catch {}
  handled.delete(tab.id);
}

// schemes the browser renders itself; anything else is handed to the OS
const BROWSER_SCHEMES =
  /^(https?|ftp|wss?|about|blank|chrome|chrome-extension|chrome-untrusted|devtools|vivaldi|view-source|javascript|data|blob|file|filesystem):/i;
const isCustomScheme = (u) => !!u && !BROWSER_SCHEMES.test(u);

const SHELL_MAX_AGE_MS = 3000; // a protocol shell is a tab that was just created
const createdAt = new Map(); // tabId -> Date.now() at tabs.onCreated

async function reapProtocolShell(tabId) {
  try {
    const born = createdAt.get(tabId);
    if (born === undefined || Date.now() - born > SHELL_MAX_AGE_MS) return; // an established tab, leave it
    const t = await chrome.tabs.get(tabId);
    const u = t.pendingUrl || t.url || "";
    dbg("reap check", tabId, { url: t.url, pending: t.pendingUrl });
    if (u !== "" && u !== "about:blank" && !isCustomScheme(u)) return;
    if ((await windowType(t.windowId)) !== "normal") return;
    await chrome.tabs.remove(tabId);
  } catch {}
}

// --- 3. fold command-line windows into the existing normal window ----------

const SETTLE_MS = 400; // let the new window's tab get its URL
const STARTUP_GRACE_MS = 30000; // session restore also creates windows with tabs

const noOpenerTabs = new Set(); // tabs created without a page opener

// Which Vivaldi window was active before a new one appeared is the whole
// trigger (Chromium only creates a window when the last active one can't hold
// tabs), so keep a short focus history. It lives in storage.session because the
// worker is routinely shut down between events; the session store is wiped
// when the browser exits.
async function noteFocus(windowId) {
  if (windowId === chrome.windows.WINDOW_ID_NONE) return;
  const type = await windowType(windowId);
  if (!type) return;
  const { focus = [] } = await chrome.storage.session.get("focus");
  if (focus[0]?.id === windowId) return;
  focus.unshift({ id: windowId, type });
  await chrome.storage.session.set({ focus: focus.slice(0, 6) });
}

// storage.session is wiped when the browser exits, and the worker is started
// as soon as the browser launches, so the first run marks the browser's start.
try {
  chrome.storage.session.get("bootAt").then(({ bootAt }) => {
    if (bootAt === undefined) chrome.storage.session.set({ bootAt: Date.now() });
  });
} catch (e) {
  dbg("storage.session unavailable", String(e));
}

chrome.windows.onFocusChanged.addListener(noteFocus);

async function otherNormalWindow(excludeId, focus) {
  const wins = await chrome.windows.getAll({ windowTypes: ["normal"] });
  const others = wins.filter((w) => w.id !== excludeId);
  if (!others.length) return null;
  const recent = focus.find((f) => f.type === "normal" && others.some((w) => w.id === f.id));
  return (recent && others.find((w) => w.id === recent.id)) || others.find((w) => w.focused) || others[0];
}

const isWebUrl = (u) => /^https?:/i.test(u || "");

async function foldLoneWindow(windowId) {
  try {
    const { bootAt = 0 } = await chrome.storage.session.get("bootAt");
    dbg("fold? win", windowId, "since boot", Date.now() - bootAt);
    if (Date.now() - bootAt < STARTUP_GRACE_MS) return; // session restore is creating windows
    const win = await chrome.windows.get(windowId, { populate: true });
    dbg("fold win", { id: win.id, type: win.type, tabs: (win.tabs || []).map((t) => [t.id, t.url, t.pendingUrl, t.openerTabId]) });
    if (win.type !== "normal" || !win.tabs || win.tabs.length !== 1) return;
    const tab = win.tabs[0];
    // Ctrl+N (start page), "open link in new window" (has an opener) and tabs
    // dragged out of another window (not created here) are all deliberate.
    if (!noOpenerTabs.has(tab.id) || !isWebUrl(tab.pendingUrl || tab.url)) return;
    // Only when a non-tabbed (app/popup) window was the active one: a new
    // window opened while a normal window was active was asked for.
    const { focus = [] } = await chrome.storage.session.get("focus");
    const before = focus.find((f) => f.id !== windowId);
    dbg("fold focus-before", before, "history", focus);
    if (!before || before.type === "normal") return;
    const target = await otherNormalWindow(windowId, focus);
    dbg("fold target", target && { id: target.id, type: target.type, focused: target.focused }, "all", (await chrome.windows.getAll()).map((w) => [w.id, w.type]));
    if (!target) return;
    await chrome.tabs.move(tab.id, { windowId: target.id, index: -1 });
    await chrome.tabs.update(tab.id, { active: true });
    await chrome.windows.update(target.id, { focused: true });
    try {
      await chrome.windows.remove(windowId); // normally already gone with its last tab
    } catch {}
  } catch {}
}

chrome.windows.onCreated.addListener((win) => {
  if (win.type === "normal") setTimeout(() => foldLoneWindow(win.id), SETTLE_MS);
});

// --- wiring ------------------------------------------------------------------

chrome.tabs.onCreated.addListener((tab) => {
  dbg("tabs.onCreated", { id: tab.id, win: tab.windowId, opener: tab.openerTabId, url: tab.url, pending: tab.pendingUrl });
  createdAt.set(tab.id, Date.now());
  if (tab.openerTabId === undefined) noOpenerTabs.add(tab.id);
  maybeRoute(tab);
});
chrome.tabs.onUpdated.addListener((tabId, info, tab) => {
  const navUrl = info.url || tab.pendingUrl || "";
  if (isCustomScheme(navUrl)) {
    setTimeout(() => reapProtocolShell(tabId), 600); // let the OS handoff fire first
    return;
  }
  if (info.url !== undefined || info.status === "loading") maybeRoute(tab);
});
chrome.tabs.onRemoved.addListener((tabId) => {
  handled.delete(tabId);
  noOpenerTabs.delete(tabId);
  createdAt.delete(tabId);
});
