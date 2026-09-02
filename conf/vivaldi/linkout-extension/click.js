// Catch link clicks that would open a new browsing context outside the
// app's origin, and reroute them to main Vivaldi before any window opens.
// Runs in every frame, including blob:/srcdoc email-body frames. Frames
// with no extension APIs (opaque origins) relay upward via postMessage.
const BRIDGE_KEY = "__penguinoLinkout";

function hasRuntime() {
  try {
    return !!chrome?.runtime?.id;
  } catch {
    return false;
  }
}

// Fail open at every step: a broken chain must degrade to a real window
// (which the service worker's window-level fallback then bounces), never
// to a swallowed click.
function bounce(url, via) {
  if (!hasRuntime()) {
    if (window.parent !== window) {
      window.parent.postMessage({ [BRIDGE_KEY]: url, via: "relay" }, "*");
    } else {
      window.open(url, "_blank", "noopener");
    }
    return;
  }
  try {
    chrome.runtime.sendMessage({ url, via }, () => {
      if (chrome.runtime.lastError) window.open(url, "_blank", "noopener");
    });
  } catch {
    window.open(url, "_blank", "noopener");
  }
}

function onClick(e) {
  if (e.defaultPrevented) return;
  if (e.type === "auxclick" && e.button !== 1) return;
  const el = e.target instanceof Element ? e.target : e.target?.parentElement;
  const a = el?.closest?.("a[href]");
  if (!a) return;
  let u;
  try {
    u = new URL(a.href, location.href);
  } catch {
    return;
  }
  if (!/^https?:$/.test(u.protocol)) return;
  if (u.origin === location.origin) return;
  const newContext =
    a.target === "_blank" || e.ctrlKey || e.metaKey || e.shiftKey || e.button === 1;
  if (!newContext) return;
  e.preventDefault();
  e.stopImmediatePropagation();
  bounce(u.href, "click");
}

addEventListener("click", onClick, true);
addEventListener("auxclick", onClick, true);

// bridge: window.open reroutes from the MAIN-world patch (same window) and
// relays from child frames that lack extension APIs
addEventListener("message", (e) => {
  const url = e.data?.[BRIDGE_KEY];
  if (typeof url !== "string" || !/^https?:\/\//i.test(url)) return;
  bounce(url, e.source === window ? e.data.via || "open-patch" : "relay");
});
