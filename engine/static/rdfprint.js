/* rdfprint.js - draws a legacy Oracle Reports layout (compiled by app/gen/rdfprint.py) with the data of one document
   (built by the database package APP_RDF).  Every object keeps the position, size, font, colours and borders it had in the
   .rdf; repeating frames repeat per record, elastic fields and frames grow and push the objects below them (Reports implicit
   anchoring), column lines stretch with their repeating frame, and the result is split into pages: objects printed on all pages
   repeat, the detail records continue on the next page and the objects below them follow the last record. */
var rdfPrint = (function () {
  "use strict";
  var EPS = 0.002;
  var NAMED = {
    black: "#000000", white: "#ffffff", red: "#ff0000", green: "#00ff00", blue: "#0000ff", yellow: "#ffff00", cyan: "#00ffff",
    magenta: "#ff00ff", darkred: "#800000", darkgreen: "#008000", darkblue: "#000080", darkyellow: "#808000", darkcyan: "#008080",
    darkmagenta: "#800080", gray: "#c0c0c0", grey: "#c0c0c0", darkgray: "#808080", darkgrey: "#808080", lightgray: "#e0e0e0", orange: "#ff8000"
  };

  function color(c) {
    if (!c) return null;
    c = String(c).toLowerCase().replace(/\s+/g, "");
    if (NAMED[c]) return NAMED[c];
    var m = /^gr[ae]y(\d+)$/.exec(c);                     // grayN: N percent black (gray4 is almost white)
    if (m) { var v = Math.round(255 * (1 - Math.min(100, +m[1]) / 100)); return "rgb(" + v + "," + v + "," + v + ")"; }
    m = /^r(\d+)g(\d+)b(\d+)$/.exec(c);                   // rNgNbN: percent per channel
    if (m) return "rgb(" + [m[1], m[2], m[3]].map(function (x) { return Math.round(255 * Math.min(100, +x) / 100); }).join(",") + ")";
    return c;
  }

  function inch(v) { return (Math.round(v * 10000) / 10000) + "in"; }

  function parseAttrs(s) {                                  // "tc=red|fw=bold" from SRW.SET_* in format triggers
    var o = {};
    (s || "").split("|").forEach(function (kv) { var i = kv.indexOf("="); if (i > 0) o[kv.slice(0, i)] = kv.slice(i + 1); });
    return o;
  }

  function applyFont(node, f, a) {
    f = f || {};
    a = a || {};
    node.style.fontFamily = "'" + (a.fn || f.f || "Arial") + "', Arial, sans-serif";
    node.style.fontSize = (a.fs || f.s || 10) + "pt";
    node.style.fontWeight = (a.fw === "bold" || (!a.fw && f.b)) ? "bold" : "normal";
    if (a.fy === "italic" || (!a.fy && f.i)) node.style.fontStyle = "italic";
    if (a.fy === "underline" || (!a.fy && f.u)) node.style.textDecoration = "underline";
    var c = color(a.tc || f.c);
    if (c) node.style.color = c;
  }

  // ------------------------------------------------------------------ barcodes
  // Fields printed with a Code 39 barcode font (IDAutomationHC39M ...) are drawn as bars: 1 = bar module, 0 = space module (wide
  // elements are two modules), a narrow gap between characters; the text is printed under the bars as the HC ("human readable") font does.
  var C39 = {
    "0": "101001101101", "1": "110100101011", "2": "101100101011", "3": "110110010101", "4": "101001101011", "5": "110100110101",
    "6": "101100110101", "7": "101001011011", "8": "110100101101", "9": "101100101101", "A": "110101001011", "B": "101101001011",
    "C": "110110100101", "D": "101011001011", "E": "110101100101", "F": "101101100101", "G": "101010011011", "H": "110101001101",
    "I": "101101001101", "J": "101011001101", "K": "110101010011", "L": "101101010011", "M": "110110101001", "N": "101011010011",
    "O": "110101101001", "P": "101101101001", "Q": "101010110011", "R": "110101011001", "S": "101101011001", "T": "101011011001",
    "U": "110010101011", "V": "100110101011", "W": "110011010101", "X": "100101101011", "Y": "110010110101", "Z": "100110110101",
    "-": "100101011011", ".": "110010101101", " ": "100110101101", "$": "100100100101", "/": "100100101001", "+": "100101001001",
    "%": "101001001001", "*": "100101101101"
  };
  function isBarcodeFont(f) { return !!(f && /idautomation.*39|3\s*of\s*9|code\s*39|\bc39|free\s*3\s*of\s*9/i.test(f.f || "")); }
  function barcode39(node, text, o) {
    var t = String(text || "").toUpperCase().replace(/^\*|\*$/g, "");
    var mods = [];
    ("*" + t + "*").split("").forEach(function (ch) { if (C39[ch]) mods.push(C39[ch]); });
    var bits = mods.join("0");
    var svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    var textH = Math.min(0.16, o.h * 0.3), barH = Math.max(o.h - textH, o.h * 0.6);
    svg.setAttribute("viewBox", "0 0 " + bits.length + " 100");
    svg.setAttribute("preserveAspectRatio", "none");
    svg.style.cssText = "display:block;width:100%;height:" + inch(barH) + ";shape-rendering:crispEdges";
    for (var i = 0; i < bits.length; ) {
      if (bits[i] === "1") {
        var j = i; while (j < bits.length && bits[j] === "1") j++;
        var r = document.createElementNS("http://www.w3.org/2000/svg", "rect");
        r.setAttribute("x", i); r.setAttribute("y", 0); r.setAttribute("width", j - i); r.setAttribute("height", 100); r.setAttribute("fill", "#000");
        svg.appendChild(r); i = j;
      } else i++;
    }
    node.textContent = "";
    node.appendChild(svg);
    var cap = document.createElement("div");
    cap.style.cssText = "text-align:center;font:" + Math.max(6, Math.round(textH * 72 * 0.8)) + "pt Arial,sans-serif;line-height:1;direction:ltr";
    cap.textContent = "*" + t + "*";
    node.appendChild(cap);
  }

  function align(a, dir) {
    return { start: "start", end: "end", center: "center", left: "left", right: "right", flush: "justify" }[a || "start"] || "start";
  }

  // ------------------------------------------------------------------ data access
  function instancesOf(inst, group) {
    if (!inst || !inst.c) return [];
    if (inst.c[group]) return inst.c[group];
    var out = [];
    Object.keys(inst.c).forEach(function (g) {
      (inst.c[g] || []).forEach(function (ch) { out = out.concat(instancesOf(ch, group)); });
    });
    return out;
  }
  function hidden(inst, name) { return !!(inst && inst.h && inst.h.indexOf(name) >= 0); }
  function attrsOf(inst, name) { return parseAttrs(inst && inst.s ? inst.s[name] : null); }

  function overlapX(a, b) { return a.x < b.x + b.w - EPS && b.x < a.x + a.w - EPS; }

  // ------------------------------------------------------------------ layout
  function Layout(doc, layout, data) {
    this.doc = doc; this.L = layout; this.D = data; this.dir = layout.dir || "ltr";
    this.items = [];        // {node, top, h, po, encl, memb}
    this.flows = [];
    this.depth = 0;
    this.sandbox = document.createElement("div");
    this.sandbox.style.cssText = "position:absolute;left:-10000px;top:0;visibility:hidden";
    document.body.appendChild(this.sandbox);
  }

  Layout.prototype.add = function (node, o, top, h, extra) {
    // print-on-page left at its default: objects inside a frame print with their frame on every page it spans,
    // objects directly in the report body print once
    var it = { node: node, top: top, h: h, x: o.x, w: o.w, po: o.po || (this.depth > 0 ? "allPage" : "firstPage"), o: o, encl: this.depth > 0,
               rootAll: !!(this.root && this.root.po === "allPage") };
    if (extra) Object.keys(extra).forEach(function (k) { it[k] = extra[k]; });
    if (o.n) node.setAttribute("data-n", o.n);
    this.items.push(it);
    return it;
  };

  Layout.prototype.box = function (o, a) {
    var n = document.createElement("div");
    n.className = "rdf-o rdf-" + o.k;
    n.style.left = inch(o.x); n.style.width = inch(Math.max(o.w, 0));
    var fill = a && (a.ff || a.bf) ? (a.ff || a.bf) : o.fill;
    if (a && a.fp === "transparent") fill = null;
    if (fill) n.style.backgroundColor = color(fill);
    var lp = a && a.bp ? a.bp : o.lp;
    var solidDefault = (o.k === "rc" || o.k === "rr" || o.k === "el");
    if ((lp && lp !== "transparent") || (!lp && solidDefault)) {
      var w = (a && a.bw) ? +a.bw : (o.lw || 0);
      n.style.border = (w > 0 ? w + "pt" : "1px") + " " + (o.dash ? "dashed" : "solid") + " " + color((a && a.bc) || o.lc || "black");
    }
    if (o.k === "rr") n.style.borderRadius = "0.08in";
    if (o.k === "el") n.style.borderRadius = "50%";
    return n;
  };

  Layout.prototype.measure = function (node, w) {
    var m = node.cloneNode(true);
    m.style.position = "static"; m.style.width = inch(w); m.style.height = "auto"; m.style.overflow = "visible"; m.style.border = "0";
    this.sandbox.appendChild(m);
    var px = m.getBoundingClientRect().height;
    this.sandbox.removeChild(m);
    return px / 96;
  };

  // place sibling objects; returns the bottom shift of every placed object (for the enclosing frame)
  Layout.prototype.placeList = function (objs, ctx, base) {
    var self = this, placed = [];
    var order = (objs || []).map(function (o, i) { return { o: o, i: i }; });
    order.sort(function (a, b) { return (a.o.y - b.o.y) || (a.i - b.i); });
    // draw in the report's order (z-order), place in top-down order: collect per object, then append in original order
    var results = new Array(order.length);
    order.forEach(function (e) {
      var o = e.o, shift = base;
      placed.forEach(function (p) {
        if (p.o.y + p.o.h <= o.y + EPS && overlapX(p.o, o)) shift = Math.max(shift, p.bottom);
      });
      var mark = self.items.length;
      if (self.depth === 0) self.root = o;                 // top-level object of the report body (print on all pages?)
      var bottom = self.place(o, ctx, shift);
      placed.push({ o: o, bottom: bottom });
      results[e.i] = { o: o, shift: shift, bottom: bottom, items: self.items.splice(mark, self.items.length - mark) };
    });
    results.forEach(function (r) { if (r) Array.prototype.push.apply(self.items, r.items); });
    return results.filter(Boolean);
  };

  // growth of a container from its children.  Expand: the design size is a minimum, the frame grows only when the moved
  // children no longer fit in it (its free space is used first).  Variable: the frame fits its contents (grows or shrinks).
  // Contract: it may only shrink to its contents.  Fixed: design size.
  function growth(o, kids, shift) {
    if (!kids.length) return 0;
    var maxNow = -1e9;
    kids.forEach(function (k) { maxNow = Math.max(maxNow, k.o.y + k.o.h + k.bottom); });
    var fit = maxNow - (o.y + o.h + shift);                  // content bottom against the frame's (shifted) design bottom
    if (o.ve === "e") return Math.max(0, fit);
    if (o.ve === "v") return fit;
    if (o.ve === "c") return Math.min(0, fit);
    return 0;
  }

  Layout.prototype.place = function (o, ctx, shift) {
    var inst = ctx.inst;
    if (hidden(inst, o.n) || o.hide) return shift;
    var a = attrsOf(inst, o.n);
    var self = this, n, g;
    switch (o.k) {
      case "rf": return this.placeRF(o, ctx, shift);
      case "xc": {                                         // one column of a matrix: its header / totals, or a row's cell
        var xi = o.inst || null;
        if (!xi) instancesOf(inst, o.g).forEach(function (c) { if (!xi && c.k === o.key) xi = c; });
        this.depth++;
        var xk = this.placeList(o.ch, { inst: xi || {}, parent: ctx }, shift);
        this.depth--;
        return shift + growth({ y: o.y, h: o.h, ve: "e" }, xk, shift);
      }
      case "fr": {
        var mx = this.matrix(o.ch, ctx);
        if (mx) o = mx.fit(o);
        n = this.box(o, a);
        var it = this.add(n, o, o.y + shift, o.h);
        this.depth++;
        var kids = this.placeList(o.ch, ctx, shift);
        this.depth--;
        g = growth(o, kids, shift);
        it.h = o.h + g;
        return shift + g;
      }
      case "fd": {
        n = this.box(o, a);
        n.dir = this.dir;
        n.style.textAlign = align(o.al, this.dir);
        applyFont(n, o.font, a);
        if (o.img) {
          var src = inst && inst.i ? inst.i[o.n] : null;
          if (src) { var img = document.createElement("img"); img.src = src; n.appendChild(img); n.classList.add("rdf-img"); }
          this.add(n, o, o.y + shift, o.h);
          return shift;
        }
        var txt;
        if (o.sys) {
          if (o.sys === "CURRENTDATE") txt = inst && inst.t ? inst.t[o.n] : "";
          else { n.setAttribute("data-sys", o.sys); txt = ""; }
        } else {
          txt = a.v != null ? a.v : (inst && inst.t ? inst.t[o.n] : null);
          if (txt == null && this.D.report && this.D.report.t) txt = this.D.report.t[o.n];   // report-level value shown in a group
        }
        if (txt != null && txt !== "" && isBarcodeFont(a.fn ? { f: a.fn } : o.font)) {
          barcode39(n, txt, o);
          this.add(n, o, o.y + shift, o.h);
          return shift;
        }
        if (txt != null && /^[\s\d.,:\/\-+%()]+$/.test(txt) && /\d/.test(txt)) {
          var num = document.createElement("span"); num.dir = "ltr"; num.textContent = txt;       // ".09" stays ".09" in RTL
          n.appendChild(num); txt = null;
        }
        if (txt != null) n.textContent = txt;
        g = 0;
        if ((o.ve === "e" || o.ve === "v") && n.textContent) {
          var h = this.measure(n, o.w);
          g = o.ve === "e" ? Math.max(0, h - o.h) : h - o.h;
        } else if (n.textContent && /\n/.test(n.textContent)) {
          // fixed field: Reports prints only the lines that fit completely
          var lh = ((a.fs || (o.font && o.font.s) || 10) * 1.15) / 72, lines = Math.max(1, Math.floor((o.h + 0.01) / lh));
          var inner = document.createElement("div");
          inner.style.maxHeight = inch(lines * lh); inner.style.overflow = "hidden";
          inner.textContent = n.textContent; n.textContent = ""; n.appendChild(inner);
        }
        this.add(n, o, o.y + shift, o.h + g);
        return shift + g;
      }
      case "tx": {
        n = this.box(o, a);
        n.dir = this.dir;
        n.style.textAlign = align(o.al, this.dir);
        applyFont(n, (o.segs && o.segs[0] && o.segs[0].font) || o.font, a);
        var refs = inst && inst.x ? inst.x[o.n] : null;
        (o.segs || []).forEach(function (s) {
          var sp = document.createElement("span");
          applyFont(sp, s.font || o.font, a);
          var t = s.t;
          if (refs) t = t.replace(/&<?([A-Za-z][A-Za-z0-9_]*)>?/g, function (m, k) { k = k.toUpperCase(); return refs[k] != null ? refs[k] : m; });
          sp.textContent = t;
          n.appendChild(sp);
        });
        this.add(n, o, o.y + shift, o.h);
        return shift;
      }
      case "ln": case "pl": {
        this.add(this.line(o, a), o, o.y + shift, o.h, { stretch: o.stretch, line: true });
        return shift;
      }
      case "rc": case "rr": case "el": case "ar": case "pg": {
        this.add(this.box(o, a), o, o.y + shift, o.h);
        return shift;
      }
      case "im": {
        this.add(this.box(o, a), o, o.y + shift, o.h);
        return shift;
      }
    }
    return shift;
  };

  Layout.prototype.line = function (o, a) {
    var n = document.createElement("div");
    n.className = "rdf-o rdf-ln";
    var w = (a && a.bw) ? +a.bw : (o.lw || 0);
    var c = color((a && a.bc) || o.lc || "black");
    var style = o.dash ? (/dot/i.test(o.dash) && !/dash/i.test(o.dash) ? "dotted" : "dashed") : "solid";
    if (o.lp === "transparent") { n.style.display = "none"; return n; }
    var bw = (w > 0 ? w + "pt" : "1px") + " " + style + " " + c;
    var p = o.pts || [];
    var vertical = o.w < 0.01, horizontal = o.h < 0.01;
    n.style.left = inch(o.x); n.style.width = inch(Math.max(o.w, 0));
    if (vertical) n.style.borderLeft = bw;
    else if (horizontal) n.style.borderTop = bw;
    else if (p.length >= 2) {                                   // diagonal: SVG
      var svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
      svg.setAttribute("width", "100%"); svg.setAttribute("height", "100%");
      svg.setAttribute("viewBox", "0 0 " + o.w + " " + o.h); svg.setAttribute("preserveAspectRatio", "none");
      var l = document.createElementNS("http://www.w3.org/2000/svg", "line");
      l.setAttribute("x1", p[0][0] - o.x); l.setAttribute("y1", p[0][1] - o.y); l.setAttribute("x2", p[1][0] - o.x); l.setAttribute("y2", p[1][1] - o.y);
      l.setAttribute("stroke", c); l.setAttribute("stroke-width", (w > 0 ? w / 72 : 1 / 96)); l.setAttribute("vector-effect", "non-scaling-stroke");
      svg.appendChild(l); n.appendChild(svg);
    }
    return n;
  };

  Layout.prototype.placeRF = function (o, ctx, shift) {
    var insts = instancesOf(ctx.inst, o.g);
    var self = this, total = 0, recs = [];
    var a = attrsOf(ctx.inst, o.n);
    var flow = { id: this.flows.length, o: o, recs: recs, top: o.y + shift, total: 0, depth: this.rfDepth = (this.rfDepth || 0) + 1,
                 rootAll: this.depth === 0 && o.po === "allPage" };   // report-level repeating frame printed on all pages (logo, QR)
    this.flows.push(flow);
    insts.forEach(function (inst, k) {
      var ictx = { inst: inst, parent: ctx };
      var instShift = shift + total;
      var mark = self.items.length;
      var boxIt = null;
      if (o.fill || (o.lp && o.lp !== "transparent")) boxIt = self.add(self.box(o, a), o, o.y + instShift, o.h, { po: "allPage" });
      var mx = self.matrix(o.ch, ictx);                  // a matrix per record (matrix with group): its own columns
      self.depth++;
      var kids = self.placeList(mx ? mx.objs : o.ch, ictx, instShift);
      self.depth--;
      var g = growth(o, kids, instShift);
      var h = o.h + g;
      if (boxIt) boxIt.h = h;
      for (var j = mark; j < self.items.length; j++) {
        var it = self.items[j];
        if (it.stretch && it.stretch.toUpperCase() === (o.n || "").toUpperCase()) it.h = (o.y + instShift + h) - it.top;
        (it.memb = it.memb || {})[flow.id] = k;          // this item belongs to record k of this repeating frame
      }
      recs.push({ top: o.y + instShift, h: h });
      total += h + (o.vsp || 0);
    });
    if (insts.length) total -= (o.vsp || 0);
    flow.total = total;
    this.rfDepth--;
    if (!insts.length) return shift;                 // no records: the area stays (objects below do not move up)
    return shift + (total - o.h);
  };

  // ------------------------------------------------------------------ matrix (cross product) reports
  // The column repeating frame (printed across) is laid out once per column of the matrix - left to right, right to left in an
  // Arabic report; the objects beyond it move over and the frames spanning it widen.  Its parts above and below the row frame
  // are the column headers and totals (bound to the column); its part inside the row frame is the cell, put into the row frame
  // once per column and bound, per row, to that row's instance of the column (same key).
  function clone(o) { return JSON.parse(JSON.stringify(o)); }
  function shiftX(o, dx) {
    o.x += dx;
    if (o.pts) o.pts.forEach(function (p) { p[0] += dx; });
    (o.ch || []).forEach(function (c) { shiftX(c, dx); });
  }

  Layout.prototype.matrix = function (objs, ctx) {
    var A = null, mo = null, R = null;
    (objs || []).forEach(function (o) { if (!A && o.k === "rf" && o.dir === "across") A = o; });
    if (!A) return null;
    objs.forEach(function (o) { if (o.k === "mx" && o.vf === A.n) mo = o; });
    objs.forEach(function (o) {
      if (R || o === A || o.k !== "rf") return;
      if (mo ? o.n === mo.hf : (o.y >= A.y - EPS && o.y + o.h <= A.y + A.h + EPS)) R = o;
    });
    var rtl = this.dir === "rtl", sgn = rtl ? -1 : 1;
    var cols = instancesOf(ctx.inst, A.g);
    var step = A.w + (A.hsp || 0), extra = Math.max(cols.length - 1, 0) * step;
    var lo = A.x, hi = A.x + A.w;
    function widen(x) {
      if (!rtl && x.x >= hi - EPS) { shiftX(x, extra); return; }
      if (rtl && x.x + x.w <= lo + EPS) { shiftX(x, -extra); return; }
      if (x.x <= lo + EPS && x.x + x.w >= hi - EPS) {
        (x.ch || []).forEach(widen);
        fit(x, rtl ? lo - extra : hi + extra);
      }
    }
    // a frame spanning the columns grows (horizontal expand) only as far as its moved contents need
    function fit(x, edge) {
      if (!rtl) {
        var r = Math.max(x.x + x.w, edge);
        (x.ch || []).forEach(function (c) { r = Math.max(r, c.x + c.w); });
        x.w = r - x.x;
      } else {
        var l = Math.min(x.x, edge);
        (x.ch || []).forEach(function (c) { l = Math.min(l, c.x); });
        x.w = x.x + x.w - l; x.x = l;
      }
    }
    function inBand(c) { return R && c.y >= R.y - EPS && c.y + c.h <= R.y + R.h + EPS; }
    function column(part, k, bind) {
      var ch = part.map(function (p) { var c = clone(p); shiftX(c, sgn * k * step); return c; });
      var x0 = Math.min.apply(null, ch.map(function (c) { return c.x; })), x1 = Math.max.apply(null, ch.map(function (c) { return c.x + c.w; }));
      var y0 = Math.min.apply(null, ch.map(function (c) { return c.y; })), y1 = Math.max.apply(null, ch.map(function (c) { return c.y + c.h; }));
      var o = { k: "xc", n: A.n + "#" + k, x: x0, y: y0, w: x1 - x0, h: y1 - y0, ch: ch, g: A.g };
      if (bind) o.inst = bind; else o.key = cols[k].k;
      return o;
    }
    var kids = A.ch || [];
    var cells = kids.filter(inBand);
    var head = kids.filter(function (c) { return !inBand(c) && !(R && c.y >= R.y + R.h - EPS); });
    var foot = kids.filter(function (c) { return !inBand(c) && R && c.y >= R.y + R.h - EPS; });
    var out = [];
    objs.forEach(function (o) {
      if (o === A || o.k === "mx") return;
      var c = clone(o);
      widen(c);
      if (o === R && cells.length) cols.forEach(function (col, k) { c.ch = (c.ch || []).concat([column(cells, k, null)]); });
      out.push(c);
    });
    cols.forEach(function (col, k) {
      if (head.length) out.push(column(head, k, col));
      if (foot.length) out.push(column(foot, k, col));
    });
    return { objs: out, fit: function (o) { var c = Object.assign({}, o, { ch: out }); fit(c, rtl ? lo - extra : hi + extra); return c; } };
  };

  // ------------------------------------------------------------------ pages
  function pageSize(L, sec) {
    var b = sec.body || { w: 8.5, h: 11 };
    if (sec.pw && sec.ph) return { w: sec.pw, h: sec.ph };
    var landscape = sec.orient === "landscape";
    var a4 = L.unit === "centimeter" || b.h > 11.02 || b.w > 8.52;
    var w = a4 ? 8.27 : 8.5, h = a4 ? 11.69 : 11;
    if (landscape) { var t = w; w = h; h = t; }
    return { w: Math.max(w, b.x + b.w), h: Math.max(h, b.y + b.h) };
  }

  // Page splitting (general): the laid-out report is one tall canvas.  A page ends at a "cut" where no text / field / image is
  // cut in two (record boundaries, gaps), at most maxRecordsPerPage records of a repeating frame per page, page breaks of
  // repeating frames honoured.  A continuation page first repeats the objects printed on all pages: those of the report body
  // itself and the header objects of every record (group instance) that continues across the cut; the content follows them.
  // Frames and boxes that span a cut are drawn on both pages, clipped.
  function splittable(it) { return it.o.k === "fr" || it.o.k === "rf" || it.o.k === "rc" || it.o.k === "rr" || it.line; }

  Layout.prototype.paginate = function (bodyH) {
    var self = this, items = this.items, flows = this.flows;
    var H = 0;
    items.forEach(function (it) { H = Math.max(H, it.top + it.h); });
    if (H <= bodyH + EPS) return [{ items: items.map(function (it) { return { it: it, top: it.top }; }) }];
    // the record (flow, index) that owns each item directly: its deepest repeating-frame membership
    items.forEach(function (it) {
      var own = null;
      Object.keys(it.memb || {}).forEach(function (f) {
        if (!own || flows[f].depth > flows[own.f].depth) own = { f: +f, k: it.memb[f] };
      });
      it.own = own;
    });
    // candidate cuts: record boundaries and object bottoms where no unsplittable object straddles
    var solid = items.filter(function (it) { return !splittable(it) && it.h > EPS; });
    var cand = {};
    items.forEach(function (it) { cand[(it.top + it.h).toFixed(4)] = 1; cand[it.top.toFixed(4)] = 1; });
    flows.forEach(function (f) { f.recs.forEach(function (r) { cand[r.top.toFixed(4)] = 1; cand[(r.top + r.h).toFixed(4)] = 1; }); });
    var cuts = Object.keys(cand).map(Number).filter(function (y) {
      return !solid.some(function (it) { return it.top < y - EPS && it.top + it.h > y + EPS; });
    }).sort(function (a, b) { return a - b; });
    // forced breaks: page break before / after the records of a repeating frame
    var forced = [];
    flows.forEach(function (f) {
      f.recs.forEach(function (r, k) {
        if (f.o.pb && k > 0) forced.push(r.top);
        if (f.o.pa && k < f.recs.length - 1) forced.push(r.top + r.h);
      });
    });
    function headersAt(y0) {
      var out = [];
      items.forEach(function (it) {
        if (it.top + it.h > y0 + EPS) return;                        // only objects above the cut repeat
        if (it.po !== "allPage") return;
        if (!it.own) { if (it.rootAll) out.push(it); return; }       // report body objects printed on all pages
        var fl = flows[it.own.f];
        if (fl.rootAll) { out.push(it); return; }                    // contents of a report-level all-pages repeating frame
        var r = fl.recs[it.own.k];
        if (r.top < y0 - EPS && r.top + r.h > y0 + EPS) out.push(it); // header of a record that continues after the cut
      });
      return out;
    }
    function tooMany(y0, c) {                                          // maxRecordsPerPage
      var bad = null;
      flows.forEach(function (f) {
        if (!f.o.max) return;
        var n = 0;
        f.recs.forEach(function (r) {
          if (r.top >= y0 - EPS && r.top < c - EPS) { n++; if (n > f.o.max && (bad === null || r.top < bad)) bad = r.top; }
        });
      });
      return bad;
    }
    var pages = [], y0 = 0, guard = 0;
    while (y0 < H - EPS && guard++ < 2000) {
      var first = pages.length === 0;
      var heads = first ? [] : headersAt(y0);
      var start = 0;
      heads.forEach(function (it) { start = Math.max(start, it.top + it.h); });
      if (start > bodyH - 0.5) {                                       // repeated headers would leave no room: only report-level ones
        heads = heads.filter(function (it) { return !it.own || flows[it.own.f].rootAll; });
        start = 0; heads.forEach(function (it) { start = Math.max(start, it.top + it.h); });
        if (start > bodyH - 0.5) { heads = []; start = 0; }
      }
      var dy = first ? 0 : start - y0;
      var limit = y0 + bodyH - (first ? 0 : start);
      var c = null;
      for (var i = cuts.length - 1; i >= 0; i--) { if (cuts[i] <= limit + EPS && cuts[i] > y0 + EPS) { c = cuts[i]; break; } }
      if (c === null) c = Math.min(limit, H);                          // one object taller than a page: cut it
      var f = forced.filter(function (y) { return y > y0 + EPS && y < c - EPS; });
      if (f.length) c = Math.min.apply(null, f);
      var over = tooMany(y0, c);
      if (over !== null && over > y0 + EPS) c = over;
      if (H - c < EPS) c = H;
      var page = { items: [] };
      heads.forEach(function (it) { page.items.push({ it: it, top: it.top }); });
      items.forEach(function (it) {
        var top = it.top, bot = it.top + it.h;
        if (splittable(it)) {
          if (bot > y0 + EPS && top < c - EPS && !(heads.indexOf(it) >= 0)) {
            var t = Math.max(top, y0), b = Math.min(bot, c);
            page.items.push({ it: it, top: t + dy, h: b - t });
          }
        } else if (top >= y0 - EPS && top < c - EPS) {
          page.items.push({ it: it, top: top + dy });
        }
      });
      pages.push(page);
      y0 = c;
    }
    return pages;
  };

  var CSS = [
    ".rdf-host{direction:ltr;padding:8px 0;background:#e9e9e9}",
    ".rdf-page{position:relative;background:#fff;margin:0 auto 14px;box-shadow:0 1px 6px rgba(0,0,0,.25);overflow:hidden;color:#000}",
    ".rdf-body{position:absolute;overflow:hidden}",
    ".rdf-o{position:absolute;box-sizing:border-box;overflow:hidden;white-space:pre-wrap;overflow-wrap:normal;word-break:normal;line-height:1.15;margin:0;padding:0}",
    ".rdf-fd,.rdf-tx{padding:0 1px}",
    ".rdf-ln{overflow:visible}.rdf-ln svg{position:absolute;left:0;top:0;overflow:visible}",
    ".rdf-img img{width:100%;height:100%;object-fit:contain;display:block}",
    "@media print{",
    " html,body{background:#fff!important}",
    " .t-Header,.t-Body-nav,.t-Footer,.t-Body-actions,.t-ButtonRegion,.no-print,.t-Body-title,.t-Breadcrumb,.t-Body-side,.t-Region-header,.t-Body-topButton{display:none!important}",
    " .t-Body-main,.t-Body-content,.t-Body-contentInner,.t-Body-wrap,.t-Region,.t-Region-body,.container,.row,.col{margin:0!important;padding:0!important;border:0!important;box-shadow:none!important;width:auto!important;max-width:none!important}",
    " .rdf-host{padding:0;background:#fff}",
    " .rdf-page{margin:0;box-shadow:none;page-break-after:always;break-after:page}",
    " .rdf-page:last-child{page-break-after:auto;break-after:auto}",
    " *{-webkit-print-color-adjust:exact;print-color-adjust:exact}",
    "}"
  ].join("\n");

  // page number placeholders inside boilerplate text: &<PageNumber> / &<TotalPages> ...
  var PAGE_TOKEN = /&<?(PhysicalPageNumber|PageNumber|LogicalPageNumber|PanelNumber)>?/gi;
  var TOTAL_TOKEN = /&<?(TotalPhysicalPages|TotalPages|TotalLogicalPages|TotalPanels)>?/gi;
  function pageTokens(node, k, total) {
    if ((node.textContent || "").indexOf("&") < 0) return;
    var w = document.createTreeWalker(node, NodeFilter.SHOW_TEXT), t;
    while ((t = w.nextNode())) {
      if (t.nodeValue.indexOf("&") >= 0) t.nodeValue = t.nodeValue.replace(TOTAL_TOKEN, String(total)).replace(PAGE_TOKEN, String(k + 1));
    }
  }

  function ensureCss() {
    if (document.getElementById("rdf-css")) return;
    var st = document.createElement("style"); st.id = "rdf-css"; st.textContent = CSS; document.head.appendChild(st);
  }

  function render(id) {
    ensureCss();
    var host = document.getElementById(id);
    var L = JSON.parse(document.getElementById(id + "_layout").textContent);
    var D = JSON.parse(document.getElementById(id + "_data").textContent);
    var sec = L.sections.main;
    var size = pageSize(L, sec);
    var lay = new Layout(host, L, D);
    var ctx = { inst: D.report };
    var top = lay.matrix(sec.objs || [], ctx);
    lay.placeList(top ? top.objs : (sec.objs || []), ctx, 0);
    var body = sec.body || { x: 0, y: 0, w: size.w, h: size.h };
    if (!(body.h > 0.5)) body = { x: body.x || 0, y: body.y || 0, w: body.w > 0.5 ? body.w : size.w, h: size.h - (body.y || 0) };
    // a matrix wider than the page (Reports would print extra panels): scale the body down to the page width
    var minX = 0, maxX = body.w;
    lay.items.forEach(function (it) { if (it.w > 0) { minX = Math.min(minX, it.x); maxX = Math.max(maxX, it.x + it.w); } });
    var scale = (maxX - minX) > body.w + 0.02 ? body.w / (maxX - minX) : 1;
    var pages = lay.paginate(body.h / scale);
    // margin objects (page numbers, page header/footer) on every page
    var margin = new Layout(host, L, D);
    margin.placeList(sec.margin || [], ctx, 0);
    lay.sandbox.remove(); margin.sandbox.remove();
    host.innerHTML = "";
    host.classList.add("rdf-host");
    pages.forEach(function (p, k) {
      var pg = document.createElement("div");
      pg.className = "rdf-page";
      pg.style.width = inch(size.w); pg.style.height = inch(size.h);
      var bd = document.createElement("div");
      bd.className = "rdf-body";
      bd.style.left = inch(body.x); bd.style.top = inch(body.y); bd.style.width = inch(body.w); bd.style.height = inch(body.h);
      var into = bd;
      if (scale !== 1 || minX < 0) {
        into = document.createElement("div");
        into.style.cssText = "position:absolute;left:0;top:0;transform-origin:0 0";
        into.style.width = inch(maxX - minX); into.style.height = inch(body.h / scale);
        into.style.transform = "scale(" + scale + ") translateX(" + inch(-minX) + ")";
        bd.appendChild(into);
      }
      p.items.forEach(function (e) {
        var n = e.it.node.cloneNode(true);
        n.style.top = inch(e.top); n.style.height = inch(Math.max(e.h != null ? e.h : e.it.h, 0));
        pageTokens(n, k, pages.length);
        into.appendChild(n);
      });
      pg.appendChild(bd);
      margin.items.forEach(function (it) {
        var n = it.node.cloneNode(true);
        n.style.top = inch(it.top); n.style.height = inch(Math.max(it.h, 0));
        var sys = n.getAttribute("data-sys");
        if (sys === "PHYSICALPAGENUMBER" || sys === "PAGENUMBER" || sys === "LOGICALPAGENUMBER" || sys === "PANELNUMBER") n.textContent = String(k + 1);
        if (sys === "TOTALPAGES" || sys === "TOTALPHYSICALPAGES" || sys === "TOTALLOGICALPAGES" || sys === "TOTALPANELS") n.textContent = String(pages.length);
        pageTokens(n, k, pages.length);
        pg.appendChild(n);
      });
      host.appendChild(pg);
    });
    // page numbers placed in the body (not the margin)
    host.querySelectorAll(".rdf-body [data-sys]").forEach(function (n) {
      var page = n.closest(".rdf-page"), k = Array.prototype.indexOf.call(host.children, page);
      var sys = n.getAttribute("data-sys");
      if (/PAGENUMBER|PANELNUMBER/.test(sys)) n.textContent = String(k + 1);
      if (/^TOTAL/.test(sys)) n.textContent = String(pages.length);
    });
    var st = document.getElementById("rdf-page-style");
    if (!st) { st = document.createElement("style"); st.id = "rdf-page-style"; document.head.appendChild(st); }
    st.textContent = "@page{size:" + inch(size.w) + " " + inch(size.h) + ";margin:0}";
    if (D.errors && window.console) console.warn("report errors:\n" + D.errors);
    return pages.length;
  }

  return { render: render, color: color };
})();
