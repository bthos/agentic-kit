// YAGA browser bootstrap — investigation: {{INVESTIGATION_ID}}
// Replace <PORT> with the value from server.json before injecting.
// Inject into the app entry HTML, or paste into devtools console on the page under test.
// Strip: agentic-kit/tools/yaga-strip.sh removes this whole block by sentinel match.
(function () { // YAGA:{{INVESTIGATION_ID}}
  var URL = "http://127.0.0.1:<PORT>"; // YAGA:{{INVESTIGATION_ID}}
  var ID = "YAGA:{{INVESTIGATION_ID}}"; // YAGA:{{INVESTIGATION_ID}}
  function send(path, payload) { try { fetch(URL + path, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(Object.assign({ id: ID, ts: Date.now() }, payload)) }).catch(function () {}); } catch (e) {} } // YAGA:{{INVESTIGATION_ID}}

  ["log", "info", "warn", "error"].forEach(function (level) { // YAGA:{{INVESTIGATION_ID}}
    var orig = console[level].bind(console); // YAGA:{{INVESTIGATION_ID}}
    console[level] = function () { var args = Array.prototype.slice.call(arguments).map(function (a) { try { return typeof a === "string" ? a : JSON.parse(JSON.stringify(a)); } catch (e) { return String(a); } }); send("/console", { level: level, args: args }); return orig.apply(null, arguments); }; // YAGA:{{INVESTIGATION_ID}}
  }); // YAGA:{{INVESTIGATION_ID}}

  window.addEventListener("error", function (e) { send("/console", { level: "error", args: [String(e.message), e.filename + ":" + e.lineno] }); }); // YAGA:{{INVESTIGATION_ID}}
  window.addEventListener("unhandledrejection", function (e) { send("/console", { level: "error", args: ["unhandledrejection", String(e.reason)] }); }); // YAGA:{{INVESTIGATION_ID}}

  var _fetch = window.fetch; // YAGA:{{INVESTIGATION_ID}}
  window.fetch = function (input, init) { var url = typeof input === "string" ? input : input.url; var method = (init && init.method) || (input && input.method) || "GET"; var t0 = Date.now(); return _fetch.apply(this, arguments).then(function (r) { send("/network", { url: url, method: method, status: r.status, ms: Date.now() - t0 }); return r; }, function (err) { send("/network", { url: url, method: method, error: String(err), ms: Date.now() - t0 }); throw err; }); }; // YAGA:{{INVESTIGATION_ID}}

  var _xhrSend = XMLHttpRequest.prototype.send; // YAGA:{{INVESTIGATION_ID}}
  var _xhrOpen = XMLHttpRequest.prototype.open; // YAGA:{{INVESTIGATION_ID}}
  XMLHttpRequest.prototype.open = function (method, url) { this.__yaga = { method: method, url: url, t0: Date.now() }; return _xhrOpen.apply(this, arguments); }; // YAGA:{{INVESTIGATION_ID}}
  XMLHttpRequest.prototype.send = function () { var self = this; this.addEventListener("loadend", function () { var m = self.__yaga || {}; send("/network", { url: m.url, method: m.method, status: self.status, ms: Date.now() - (m.t0 || Date.now()) }); }); return _xhrSend.apply(this, arguments); }; // YAGA:{{INVESTIGATION_ID}}
})(); // YAGA:{{INVESTIGATION_ID}}
