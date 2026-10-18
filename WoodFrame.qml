import QtQuick

// A Stardew-style wooden frame: dark outline, bevelled orange wood with a
// little grain, then a parchment panel, all with notched pixel corners.
// `unit` is one art pixel; content goes inside `inset`.
Canvas {
  id: root

  property int unit: 3
  property int band: 3
  property color outline: "#3b1d0c"
  property color wood: "#d27b33"
  property color woodLight: "#f0a95b"
  property color woodDark: "#9a4c1c"
  property color inner: "#6b3416"
  property color paper: "#fbe3b0"
  property color paperShade: "#efcd8c"

  readonly property int inset: (band + 2) * unit

  antialiasing: false
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onUnitChanged: requestPaint()
  onPaperChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var u = unit, w = Math.round(width), h = Math.round(height)
    if (w < 6 * u || h < 6 * u) return

    function rect(x, y, rw, rh, color) {
      ctx.fillStyle = color
      ctx.fillRect(x, y, rw, rh)
    }
    function notched(x, y, rw, rh, color) {
      rect(x + u, y, rw - 2 * u, rh, color)
      rect(x, y + u, rw, rh - 2 * u, color)
    }

    notched(0, 0, w, h, outline)
    notched(u, u, w - 2 * u, h - 2 * u, wood)
    rect(2 * u, u, w - 4 * u, u, woodLight)
    rect(u, 2 * u, u, h - 4 * u, woodLight)
    rect(2 * u, h - 2 * u, w - 4 * u, u, woodDark)
    rect(w - 2 * u, 2 * u, u, h - 4 * u, woodDark)

    if (band >= 3) {
      for (var x = 5 * u; x < w - 6 * u; x += 11 * u) {
        rect(x, 2 * u, 3 * u, u, woodDark)
        rect(x + 5 * u, h - 3 * u, 2 * u, u, woodLight)
      }
    }

    var b = (band + 1) * u
    notched(b, b, w - 2 * b, h - 2 * b, inner)
    notched(b + u, b + u, w - 2 * b - 2 * u, h - 2 * b - 2 * u, paper)
    rect(b + 2 * u, h - b - 2 * u, w - 2 * b - 4 * u, u, paperShade)
    rect(w - b - 2 * u, b + 2 * u, u, h - 2 * b - 4 * u, paperShade)
  }
}
