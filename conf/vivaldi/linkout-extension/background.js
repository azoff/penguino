// The vivaldi-apps instance should never browse: any tab that lands in a
// *normal* (tabbed) window here belongs in the main Vivaldi instance.
// App windows and popups (OAuth flows) are left untouched.
const handled = new Set();

async function maybeBounce(tab) {
  if (!tab || tab.id === undefined || handled.has(tab.id)) return;
  const url = tab.pendingUrl || tab.url;
  if (!url || !/^https?:\/\//i.test(url)) return;
  let win;
  try {
    win = await chrome.windows.get(tab.windowId);
  } catch {
    return;
  }
  if (win.type !== "normal") return;
  handled.add(tab.id);
  chrome.runtime.sendNativeMessage("com.penguino.linkout", { url, via: "window-fallback" }, (resp) => {
    if (chrome.runtime.lastError || !resp || !resp.ok) {
      // host missing or refused: keep the tab so the link isn't lost
      handled.delete(tab.id);
      console.warn("linkout failed:", chrome.runtime.lastError?.message, resp);
      return;
    }
    chrome.tabs.remove(tab.id).catch(() => {});
  });
}

// direct bounces from the content scripts (no window ever opens)
chrome.runtime.onMessage.addListener((msg) => {
  if (msg && typeof msg.url === "string" && /^https?:\/\//i.test(msg.url)) {
    chrome.runtime.sendNativeMessage(
      "com.penguino.linkout",
      { url: msg.url, via: msg.via || "content" },
      () => {
        void chrome.runtime.lastError;
      }
    );
  }
});

chrome.tabs.onCreated.addListener(maybeBounce);
chrome.tabs.onUpdated.addListener((tabId, info, tab) => {
  if (info.status === "loading") maybeBounce(tab);
});
chrome.tabs.onRemoved.addListener((tabId) => handled.delete(tabId));
