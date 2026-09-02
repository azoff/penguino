// MAIN-world patch: reroute featureless cross-origin window.open() calls to
// main Vivaldi. Calls WITH a features string (width=,height=...) are OAuth-
// style popups and pass through untouched.
(() => {
  const orig = window.open;
  window.open = function (url, target, features) {
    try {
      if (url && !features) {
        const u = new URL(url, location.href);
        if (/^https?:$/.test(u.protocol) && u.origin !== location.origin) {
          // postMessage, not CustomEvent: event.detail is stored per JS
          // world in Blink, so the isolated-world bridge would see null
          window.postMessage({ __penguinoLinkout: u.href, via: "open-patch" }, "*");
          return null;
        }
      }
    } catch {}
    return orig.apply(this, arguments);
  };
})();
