.pragma library

// The cast, drawn on a 32x40 pixel grid.
//
// Every character shares one skeleton: a pose is a handful of numbers
// (lean, face offset, arm targets, ...) computed from the clock, so each
// stretch animation works for the whole cast. A character supplies its
// colours, body outline, mouth and extras (basil, ears, cap). draw() only
// fills whole grid cells, so sprites stay crisp at any integer scale.

var W = 32
var H = 40
var ICON_W = 10
var ICON_H = 12

// Arm targets for the left arm, relative to its shoulder: [elbowX, elbowY,
// handX, handY]. Negative x points away from the body; the right arm mirrors.
var arms = {
  rest: [-2, 3, -3, 6],
  hips: [-4, 2, -1, 5],
  squeeze: [-4, 1, -6, -1],
  up: [-3, -6, -4, -12],
  behindHead: [-5, -6, 1, -8]
}

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

// Ramp 0 -> 1 over the first `share` of a 0..1 span.
function ramp(local, share) { return clamp(local / share, 0, 1) }

function blinking(t) { return (t % 3.7) > 3.55 }

// The pose for `name` at `t` seconds into it; `progress` is 0..1 through
// the current exercise.
function pose(name, t, progress, talking) {
  var p = {
    lean: 0, fx: 0, fy: 0, top: 0, shoulderDy: 0, ridgeShift: 0, jump: 0,
    left: arms.rest, right: arms.rest, behind: false,
    eyes: blinking(t) ? "closed" : "open", brows: 0, mouth: "smile",
    chin: false, sway: Math.floor(t * 2) % 2
  }
  var phase, half, local

  switch (name) {
  case "talk":
    p.brows = -1
    p.right = [-3, -3, -4 - (Math.floor(t / 0.3) % 2), -8]
    p.mouth = talking && Math.floor(t / 0.14) % 2 === 0 ? "talk" : "smile"
    break
  case "neckTilt":
    half = progress < 0.5 ? 0 : 1
    local = (progress - half * 0.5) / 0.5
    p.lean = Math.round((half ? -3 : 3) * ramp(local, 0.2))
    p.eyes = "closed"
    break
  case "chinTuck":
    phase = (t % 3) / 3
    if (phase < 0.5) { p.fy = 1; p.top = 1; p.chin = true; p.mouth = "flat" }
    p.left = arms.hips
    p.right = arms.hips
    break
  case "shoulderRoll":
    p.shoulderDy = [0, -2, -2, -1][Math.floor(t / 0.4) % 4]
    p.top = p.shoulderDy < 0 ? -1 : 0
    break
  case "scapula":
    phase = (t % 3) / 3
    p.left = phase < 0.6 ? arms.squeeze : arms.rest
    p.right = p.left
    if (phase < 0.6) { p.mouth = "o"; p.eyes = "happy" }
    break
  case "twist":
    half = progress < 0.5 ? 0 : 1
    local = (progress - half * 0.5) / 0.5
    p.fx = Math.round((half ? -2 : 2) * ramp(local, 0.2))
    p.ridgeShift = p.fx
    p.left = arms.hips
    p.right = arms.hips
    break
  case "reachUp":
    phase = (t % 4) / 4
    p.left = arms.up
    p.right = arms.up
    p.top = phase < 0.5 ? -1 : 0
    p.eyes = "closed"
    p.mouth = phase < 0.5 ? "o" : "smile"
    break
  case "chestOpen":
    phase = (t % 4) / 4
    p.left = arms.behindHead
    p.right = arms.behindHead
    p.behind = true
    p.fy = phase < 0.5 ? -1 : 0
    p.eyes = "happy"
    break
  case "cheer":
    p.jump = (t % 0.5) < 0.25 ? -2 : 0
    p.left = arms.up
    p.right = arms.up
    p.eyes = "happy"
    p.mouth = "talk"
    break
  }
  return p
}

// Fill a run of cells [x0, x1] on row y.
function painter(ctx, unit, ox, oy) {
  return function(x0, x1, y, color) {
    if (x1 < x0) return
    ctx.fillStyle = color
    ctx.fillRect(ox + x0 * unit, oy + y * unit, (x1 - x0 + 1) * unit, unit)
  }
}

function line(run, x0, y0, x1, y1, color) {
  var dx = Math.abs(x1 - x0), sx = x0 < x1 ? 1 : -1
  var dy = -Math.abs(y1 - y0), sy = y0 < y1 ? 1 : -1
  var err = dx + dy
  for (var guard = 0; guard < 64; guard++) {
    run(x0, x0, y0, color)
    if (x0 === x1 && y0 === y1) return
    var e2 = 2 * err
    if (e2 >= dy) { err += dy; x0 += sx }
    if (e2 <= dx) { err += dx; y0 += sy }
  }
}

function drawArm(run, sx, sy, spec, mirror, c) {
  var m = mirror ? -1 : 1
  var ex = sx + spec[0] * m, ey = sy + spec[1]
  var hx = sx + spec[2] * m, hy = sy + spec[3]
  line(run, sx, sy, ex, ey, c.arm)
  line(run, ex, ey, hx, hy, c.arm)
  var x = mirror ? hx : hx - 1
  run(x, x + 1, hy, c.hand)
  run(x, x, hy + 1, c.hand)
  run(x + 1, x + 1, hy + 1, c.handEdge)
}

// A rounded column body from row `top` to `bottom`, sheared by g.dx.
// `shade(x, y, l, r)` picks the fill colour for each inner cell.
function roundedBody(g, top, bottom, L, R, shade) {
  for (var y = top; y <= bottom; y++) {
    var o = g.dx(y), l = L + o, r = R + o
    if (y === top || y === bottom) { g.body(l + 2, r - 2, y, g.c.outline); continue }
    if (y === top + 1 || y === bottom - 1) {
      g.body(l + 1, l + 1, y, g.c.outline)
      g.body(r - 1, r - 1, y, g.c.outline)
      for (var x1 = l + 2; x1 <= r - 2; x1++) g.body(x1, x1, y, shade(x1, y, l, r))
      continue
    }
    g.body(l, l, y, g.c.outline)
    g.body(r, r, y, g.c.outline)
    for (var x = l + 1; x <= r - 1; x++) g.body(x, x, y, shade(x, y, l, r))
  }
}

// Paint a tiny sprite (rows of palette letters) at (x, y); `mirror` flips it.
function stamp(g, rows, x, y, colors, mirror) {
  for (var r = 0; r < rows.length; r++) {
    var row = rows[r]
    for (var i = 0; i < row.length; i++) {
      var color = colors[row[mirror ? row.length - 1 - i : i]]
      if (color) g.body(x + i, x + i, y + r, color)
    }
  }
}

function smile(g, y) {
  var f = g.f, c = g.c, p = g.p
  if (p.mouth === "talk") {
    g.body(15 + f, 16 + f, y, c.mouth)
    g.body(15 + f, 16 + f, y + 1, c.tongue)
  } else if (p.mouth === "o" || p.mouth === "flat") {
    g.body(15 + f, 16 + f, y + 1, c.mouth)
  } else {
    g.body(14 + f, 14 + f, y, c.mouth)
    g.body(15 + f, 16 + f, y + 1, c.mouth)
    g.body(17 + f, 17 + f, y, c.mouth)
  }
}

var shared = {
  outline: "#4a2410",
  eye: "#2a1406",
  white: "#ffffff",
  cheek: "#f2876a",
  mouth: "#8c2f14",
  tongue: "#f06f6f",
  shadow: "rgba(60, 30, 10, 0.28)"
}

function colors(own) {
  var out = {}
  for (var k in shared) out[k] = shared[k]
  for (var j in own) out[j] = own[j]
  return out
}

var characters = {
  // Rigo the Rigatoni: a ridged pasta tube with a basil sprig and a
  // handlebar moustache.
  rigo: {
    id: "rigo",
    name: "Rigo",
    portrait: "#f3cf8f",
    L: 10, R: 21, T: 8, B: 31,
    eyeRow: 7, shoulderRow: 12,
    colors: colors({
      base: "#f6bd4c", ridge: "#e8a438", light: "#ffe08f", shade: "#d48a2a",
      hole: "#8a4416", holeDeep: "#552409", brow: "#6b3416", stache: "#3d1d0c",
      leaf: "#4f9a3a", leafLight: "#8fd160", leafDark: "#2f6b24",
      arm: "#4a2410", leg: "#4a2410", hand: "#fffaf0", handEdge: "#cdb89a", shoe: "#5a2a12"
    }),
    body: function(g) {
      var c = g.c, p = g.p, T = g.T, B = g.B
      for (var y = T; y <= B; y++) {
        var o = g.dx(y), l = g.L + o, r = g.R + o
        if (y === T || y === B) { g.body(l + 1, r - 1, y, c.outline); continue }
        g.body(l, l, y, c.outline)
        g.body(r, r, y, c.outline)
        if (y === T + 1) {
          g.body(l + 1, r - 1, y, c.light)
          g.body(l + 3, r - 3, y, c.hole)
        } else if (y === T + 2) {
          g.body(l + 1, l + 1, y, c.light)
          g.body(l + 2, r - 2, y, c.hole)
          g.body(l + 4, r - 4, y, c.holeDeep)
          g.body(r - 1, r - 1, y, c.light)
        } else if (y === T + 3) {
          g.body(l + 1, r - 1, y, c.light)
        } else {
          for (var x = l + 1; x <= r - 1; x++) {
            var col = c.base
            if (((x - l - p.ridgeShift) % 3 + 3) % 3 === 0) col = c.ridge
            if (x === l + 2) col = c.light
            if (x >= r - 1 || y === B - 1) col = c.shade
            g.body(x, x, y, col)
          }
        }
      }
    },
    mouth: function(g) {
      var f = g.f, y = g.fy, c = g.c
      g.body(13 + f, 18 + f, y + 11, c.stache)
      g.body(11 + f, 11 + f, y + 11, c.stache)
      g.body(20 + f, 20 + f, y + 11, c.stache)
      g.body(11 + f, 14 + f, y + 12, c.stache)
      g.body(17 + f, 20 + f, y + 12, c.stache)
      smile(g, y + 13)
      if (g.p.chin) g.body(14 + f, 17 + f, y + 16, c.shade)
    },
    extras: function(g) {
      var c = g.c, T = g.T, s = g.p.sway
      var lx = g.dx(T) + s
      g.body(16 + lx - s, 16 + lx - s, T - 1, c.leafDark)
      g.body(17 + lx, 18 + lx, T - 5, c.leafLight)
      g.body(16 + lx, 19 + lx, T - 4, c.leaf)
      g.body(17 + lx, 17 + lx, T - 4, c.leafLight)
      g.body(15 + lx, 18 + lx, T - 3, c.leaf)
      g.body(19 + lx, 19 + lx, T - 3, c.leafDark)
      g.body(15 + lx, 17 + lx, T - 2, c.leafDark)
      g.body(13 + lx, 14 + lx, T - 3, c.leaf)
      g.body(14 + lx, 14 + lx, T - 2, c.leafDark)
    },
    icon: [
      "....dg....",
      "..oooooo..",
      ".ollllllo.",
      ".olhhhhlo.",
      ".obbbbbbo.",
      ".obebbebo.",
      ".obebbebo.",
      ".ocbbbbco.",
      ".mmmmmmmm.",
      ".obbrrbbo.",
      ".osssssso.",
      "..oooooo.."
    ],
    iconColors: { o: "outline", l: "light", h: "holeDeep", b: "base", e: "eye",
      m: "stache", s: "shade", c: "cheek", r: "mouth", g: "leafLight", d: "leaf" }
  },

  // Mochi the Cat: an orange tabby with a waving tail.
  mochi: {
    id: "mochi",
    name: "Mochi",
    portrait: "#f6d6a6",
    L: 9, R: 22, T: 12, B: 31,
    eyeRow: 5, shoulderRow: 10,
    colors: colors({
      base: "#f2a54a", stripe: "#d0742a", light: "#ffc979", shade: "#dc8a36",
      belly: "#fde3b8", ear: "#f59ab0", nose: "#ef7f97", whisker: "#6b4a3a",
      arm: "#b4601f", leg: "#8a4416", hand: "#fde3b8", handEdge: "#e2c08f", shoe: "#d9802f"
    }),
    body: function(g) {
      var c = g.c, T = g.T, B = g.B, p = g.p
      // Tail behind the body, swishing with the clock.
      var tx = g.R + g.dx(B - 4), ty = B - 3
      var tip = p.sway ? 1 : 0
      var tail = [[1, 0], [2, -1], [3, -2], [3, -3], [3, -4], [3 + tip, -5], [2 + tip, -6]]
      for (var i = 0; i < tail.length; i++) {
        g.body(tx + tail[i][0], tx + tail[i][0] + 1, ty + tail[i][1], c.outline)
        if (i < tail.length - 1) g.body(tx + tail[i][0], tx + tail[i][0], ty + tail[i][1], c.base)
      }
      roundedBody(g, T, B, g.L, g.R, function(x, y, l, r) {
        var cx = x - l
        if (y >= T + 13 && y <= B - 2 && cx >= 4 && cx <= r - l - 4) return c.belly
        if (y >= T + 1 && y <= T + 3 && (cx === 4 || cx === 6 || cx === 7 || cx === 9)) return c.stripe
        if (cx === 2) return c.light
        if (cx >= r - l - 1) return c.shade
        return c.base
      })
      // Ears.
      var ear = ["o...", "oo..", "opo.", "obpo"]
      var e = { o: c.outline, p: c.ear, b: c.base }
      var o = g.dx(T - 2)
      stamp(g, ear, g.L + 1 + o, T - 4, e, false)
      stamp(g, ear, g.R - 4 + o, T - 4, e, true)
    },
    mouth: function(g) {
      var f = g.f, y = g.fy + 10, c = g.c, p = g.p
      g.body(15 + f, 16 + f, y, c.nose)
      if (p.mouth === "talk") {
        g.body(15 + f, 16 + f, y + 1, c.mouth)
        g.body(15 + f, 16 + f, y + 2, c.tongue)
      } else if (p.mouth === "o" || p.mouth === "flat") {
        g.body(15 + f, 16 + f, y + 2, c.mouth)
      } else {
        g.body(14 + f, 14 + f, y + 1, c.outline)
        g.body(15 + f, 16 + f, y + 2, c.outline)
        g.body(17 + f, 17 + f, y + 1, c.outline)
      }
      if (p.chin) g.body(14 + f, 17 + f, y + 4, c.shade)
      // Whiskers poke out past the cheeks.
      var w = g.dx(y)
      g.body(g.L - 2 + w, g.L + 1 + w, y, c.whisker)
      g.body(g.L - 1 + w, g.L + 1 + w, y + 2, c.whisker)
      g.body(g.R - 1 + w, g.R + 2 + w, y, c.whisker)
      g.body(g.R - 1 + w, g.R + 1 + w, y + 2, c.whisker)
    },
    extras: function(g) {},
    icon: [
      "o........o",
      "oo......oo",
      "opoooooopo",
      "obbsbbsbbo",
      "obbbbbbbbo",
      "obebbbbebo",
      "obebbbbebo",
      "ocbbnnbbco",
      "obbobbobbo",
      "obbboobbbo",
      "obbbbbbbbo",
      ".oooooooo."
    ],
    iconColors: { o: "outline", p: "ear", b: "base", s: "stripe", e: "eye",
      c: "cheek", n: "nose" }
  },

  // Porcini the Mushroom: a calm forest fellow under a brown cap.
  porcini: {
    id: "porcini",
    name: "Porcini",
    portrait: "#e7d6ad",
    L: 11, R: 20, T: 14, B: 31,
    eyeRow: 3, shoulderRow: 8,
    colors: colors({
      base: "#f5e8c8", light: "#fff7e3", shade: "#dccaa2",
      cap: "#9c5a2b", capLight: "#c27c45", capDark: "#6b3818", speck: "#e0aa6e",
      gill: "#efd6a2",
      arm: "#6b3818", leg: "#6b3818", hand: "#f5e8c8", handEdge: "#d4c095", shoe: "#6b3818"
    }),
    body: function(g) {
      var c = g.c, T = g.T, B = g.B
      // Bulbous stem, a little wider near the ground.
      for (var y = T; y <= B; y++) {
        var o = g.dx(y), bulge = y >= B - 5 && y < B ? 1 : 0
        var l = g.L + o - bulge, r = g.R + o + bulge
        if (y === B) { g.body(l + 2, r - 2, y, c.outline); continue }
        g.body(l, l, y, c.outline)
        g.body(r, r, y, c.outline)
        for (var x = l + 1; x <= r - 1; x++)
          g.body(x, x, y, x === l + 1 ? c.light : x >= r - 1 || y === B - 1 ? c.shade : c.base)
      }
    },
    mouth: function(g) {
      smile(g, g.fy + 11)
      if (g.p.chin) g.body(14 + g.f, 17 + g.f, g.fy + 14, g.c.shade)
    },
    extras: function(g) {
      var c = g.c, T = g.T
      // Dome cap: half-widths from the top row down, then the gills.
      var widths = [4, 7, 9, 10, 11, 11, 11, 11]
      var top = T - 10
      for (var i = 0; i < widths.length; i++) {
        var y = top + i, o = g.dx(y), hw = widths[i]
        var l = 16 - hw + o, r = 15 + hw + o
        if (i === 0) { g.body(l, r, y, c.outline); continue }
        g.body(l, l, y, c.outline)
        g.body(r, r, y, c.outline)
        for (var x = l + 1; x <= r - 1; x++) {
          var col = c.cap
          if (i <= 3 && x - l <= hw - 2) col = c.capLight
          if (x >= r - 2 || i === widths.length - 1) col = c.capDark
          g.body(x, x, y, col)
        }
      }
      var specks = [[13, 2], [18, 1], [21, 4], [10, 5], [16, 4]]
      for (var s = 0; s < specks.length; s++) {
        var sy = top + specks[s][1]
        g.body(specks[s][0] + g.dx(sy), specks[s][0] + g.dx(sy), sy, c.speck)
      }
      var gy = top + widths.length
      var go = g.dx(gy)
      g.body(5 + go, 26 + go, gy, c.outline)
      g.body(7 + go, 24 + go, gy, c.gill)
      g.body(10 + go, 21 + go, gy + 1, c.outline)
      g.body(11 + go, 20 + go, gy + 1, c.gill)
    },
    icon: [
      "...oooo...",
      ".ohhccoo..",
      "ohhcccccco",
      "occsccccco",
      "occccccsco",
      "oddddddddo",
      "..oSSSSo..",
      "..oeSSeo..",
      "..oeSSeo..",
      "..oSrrSo..",
      "..oSSSTo..",
      "...oooo..."
    ],
    iconColors: { o: "outline", h: "capLight", c: "cap", s: "speck", d: "gill",
      S: "base", T: "shade", e: "eye", r: "mouth" }
  }
}

var ids = ["rigo", "mochi", "porcini"]

function character(id) { return characters[id] || characters.rigo }

// Draw character `id` with its top-left grid cell at (ox, oy).
function draw(ctx, unit, ox, oy, p, id) {
  var ch = character(id)
  var c = ch.colors
  var run = painter(ctx, unit, ox, oy)
  var L = ch.L, R = ch.R, B = ch.B
  var T = ch.T + p.top
  var jy = p.jump

  var g = {
    p: p, c: c, L: L, R: R, T: T, B: B,
    run: run,
    body: function(x0, x1, y, color) { run(x0, x1, y + jy, color) },
    dx: function(y) { return Math.round(p.lean * (B - y) / (B - ch.T)) }
  }

  // Ground shadow stays put while the character hops.
  if (jy < 0) run(L + 2, R - 2, B + 5, c.shadow)
  else run(L, R, B + 5, c.shadow)

  var shoulderY = T + ch.shoulderRow + p.shoulderDy
  var ls = [L + g.dx(shoulderY), shoulderY + jy]
  var rs = [R + g.dx(shoulderY), shoulderY + jy]

  if (p.behind) {
    drawArm(run, ls[0], ls[1], p.left, false, c)
    drawArm(run, rs[0], rs[1], p.right, true, c)
  }

  for (var ly = B + 1; ly <= B + 3; ly++) {
    g.body(13, 13, ly, c.leg)
    g.body(18, 18, ly, c.leg)
  }
  g.body(12, 13, B + 3, c.shoe)
  g.body(11, 13, B + 4, c.shoe)
  g.body(18, 19, B + 3, c.shoe)
  g.body(18, 20, B + 4, c.shoe)

  ch.body(g)

  // Face, carried along by the lean at eye height.
  g.f = g.dx(T + ch.eyeRow + 1) + p.fx
  g.fy = T + p.fy + ch.eyeRow - 7
  var f = g.f, fy = g.fy

  if (c.brow) {
    var browY = fy + 5 + p.brows
    g.body(12 + f, 13 + f, browY, c.brow)
    g.body(18 + f, 19 + f, browY, c.brow)
  }

  function eye(ex) {
    if (p.eyes === "closed") {
      g.body(ex, ex + 1, fy + 8, c.eye)
    } else if (p.eyes === "happy") {
      g.body(ex, ex + 1, fy + 7, c.eye)
      g.body(ex - 1, ex - 1, fy + 8, c.eye)
      g.body(ex + 2, ex + 2, fy + 8, c.eye)
    } else {
      for (var ey = fy + 7; ey <= fy + 9; ey++) g.body(ex, ex + 1, ey, c.eye)
      g.body(ex, ex, fy + 7, c.white)
    }
  }
  eye(12 + f)
  eye(18 + f)

  g.body(11 + f, 12 + f, fy + 10, c.cheek)
  g.body(19 + f, 20 + f, fy + 10, c.cheek)

  ch.mouth(g)
  ch.extras(g)

  if (!p.behind) {
    drawArm(run, ls[0], ls[1], p.left, false, c)
    drawArm(run, rs[0], rs[1], p.right, true, c)
  }
}

// The 10x12 bar icon for character `id`.
function drawIcon(ctx, unit, ox, oy, id) {
  var ch = character(id)
  var run = painter(ctx, unit, ox, oy)
  for (var y = 0; y < ch.icon.length; y++)
    for (var x = 0; x < ch.icon[y].length; x++) {
      var key = ch.iconColors[ch.icon[y][x]]
      if (key) run(x, x, y, ch.colors[key])
    }
}
