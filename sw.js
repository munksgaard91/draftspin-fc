// Service worker: viser besked, når det er din tur i draften, og gør appen klar til at åbne uden forbindelse.
var CACHE = "dsfc-shell-v42";
var FACES = "dsfc-faces-v1"; // spillerbilleder, hentes af siden ved første start (se preloadFaces i index.html)
var SCOPE = self.registration.scope;
var LIB = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.min.js";
var BADGES = "ARS AVL BOU BRE BHA CHE COV CRY EVE FUL HUL IPS LEE LIV MCI MUN NEW NFO SUN TOT".split(" ");
var SHELL = [SCOPE, SCOPE + "manifest.webmanifest", SCOPE + "icons/icon-192.png", SCOPE + "icons/icon-180.png", SCOPE + "favicon.png", SCOPE + "badges/pl-logo.svg"].concat(BADGES.map(function (c) { return SCOPE + "badges/" + c + ".png"; }));

self.addEventListener("install", function (e) {
  e.waitUntil(caches.open(CACHE).then(function (c) {
    var jobs = SHELL.map(function (u) { return c.add(u).catch(function () {}); });
    jobs.push(fetch(LIB, { mode: "no-cors" }).then(function (r) { return c.put(LIB, r); }).catch(function () {}));
    return Promise.all(jobs);
  }).then(function () { return self.skipWaiting(); }));
});
self.addEventListener("activate", function (e) {
  e.waitUntil(caches.keys().then(function (ks) {
    return Promise.all(ks.filter(function (k) { return k.indexOf("dsfc-shell-") === 0 && k !== CACHE; }).map(function (k) { return caches.delete(k); }));
  }).then(function () { return self.clients.claim(); }));
});

// Nøgle: alle sidens adresser (med ?code=, ?u= osv.) gemmes som én side.
function keyFor(req) {
  var u = new URL(req.url);
  if (req.mode === "navigate" || u.pathname === new URL(SCOPE).pathname + "index.html") return SCOPE;
  return u.origin + u.pathname;
}
// Netværk først, men falder tilbage på det gemte efter 3 sekunder eller ved fejl.
function networkFirst(req) {
  var key = keyFor(req);
  return caches.open(CACHE).then(function (c) {
    return new Promise(function (resolve) {
      var done = false;
      function fallback() {
        c.match(key).then(function (hit) { if (!done) { done = true; resolve(hit || Response.error()); } });
      }
      // en bevidst opdatering (?u=) må vente længere på nettet, ellers får brugeren den gamle side igen
      var wait = new URL(req.url).searchParams.has("u") ? 10000 : 3000;
      var timer = setTimeout(function () { if (!done) fallback(); }, wait);
      fetch(req).then(function (r) {
        clearTimeout(timer);
        if (r && r.ok) { c.put(key, r.clone()); }
        if (!done) { done = true; resolve(r); }
      }, function () { clearTimeout(timer); fallback(); });
    });
  });
}
// Gemt først, opdateres i baggrunden (bibliotek og skrifttyper).
function staleRevalidate(req) {
  return caches.open(CACHE).then(function (c) {
    return c.match(req).then(function (hit) {
      var net = fetch(req).then(function (r) { if (r && (r.ok || r.type === "opaque")) c.put(req, r.clone()); return r; }).catch(function () { return hit || Response.error(); });
      return hit || net;
    });
  });
}
self.addEventListener("fetch", function (e) {
  var req = e.request;
  if (req.method !== "GET") return;
  var u = new URL(req.url);
  if (u.origin === location.origin) {
    if (req.cache === "no-store" || u.pathname.indexOf("sw.js") !== -1) return; // versionstjek og SW-opdatering går altid direkte
    e.respondWith(networkFirst(req));
  } else if (u.hostname.slice(-12) === ".supabase.co" && u.pathname.indexOf("/storage/v1/object/public/faces/") === 0) {
    e.respondWith(caches.open(FACES).then(function (c) { return c.match(req.url).then(function (hit) { return hit || fetch(req); }); }));
  } else if (u.hostname === "cdn.jsdelivr.net" || u.hostname === "fonts.googleapis.com" || u.hostname === "fonts.gstatic.com") {
    e.respondWith(staleRevalidate(req));
  }
});

self.addEventListener("push", function (e) {
  var d = {};
  try { d = e.data.json(); } catch (x) {}
  // WebKit tilbagekalder abonnementet, hvis en push ikke viser en notifikation. Derfor vises den altid; er appen synlig, er den lydløs og lukkes igen med det samme.
  // (Serveren sender ikke push til en spiller, der har appen åben, så det er kun et sikkerhedsnet.)
  e.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(function (cs) {
    var visible = cs.some(function (c) { return c.visibilityState === "visible"; });
    var tag = d.tag || "draftspin";
    return self.registration.showNotification(d.title || "PL Draft", {
      body: d.body || "",
      tag: tag,
      icon: "icons/icon-192.png",
      renotify: !visible,
      silent: visible
    }).then(function () {
      if (!visible) return;
      return new Promise(function (r) { setTimeout(r, 1500); }).then(function () {
        return self.registration.getNotifications({ tag: tag }).then(function (ns) { ns.forEach(function (n) { n.close(); }); });
      });
    });
  }));
});
self.addEventListener("notificationclick", function (e) {
  e.notification.close();
  e.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(function (cs) {
    for (var i = 0; i < cs.length; i++) { if ("focus" in cs[i]) return cs[i].focus(); }
    return self.clients.openWindow("./");
  }));
});
