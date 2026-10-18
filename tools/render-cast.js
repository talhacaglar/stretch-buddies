#!/usr/bin/env node
// Render every character in a few poses to a PNG contact sheet, straight
// from Art.js, so new characters and poses can be reviewed without
// reloading the shell.
//
//   node tools/render-cast.js [out.png] [unit]
//
// Needs only Node; the PNG is written by hand (zlib + CRC).
const fs = require("fs")
const path = require("path")
const vm = require("vm")
const zlib = require("zlib")

const out = process.argv[2] || "cast.png"
const unit = parseInt(process.argv[3] || "6", 10)

// Art.js is a QML JavaScript library: drop the pragma and run it in an
// empty sandbox context, then read its globals from there.
const source = fs.readFileSync(path.join(__dirname, "..", "Art.js"), "utf8")
  .replace(/^\.pragma library\s*$/m, "")
const Art = vm.createContext({})
vm.runInContext(source, Art, { filename: "Art.js" })

const poses = [
  ["idle", 0, 0], ["talk", 0.1, 0, true], ["neckTilt", 2, 0.3],
  ["shoulderRoll", 0.5, 0], ["twist", 2, 0.3], ["reachUp", 0.5, 0], ["cheer", 0.1, 0]
]

const pad = 2 * unit
const cellW = Art.W * unit + pad, cellH = Art.H * unit + pad
const width = cellW * poses.length + pad, height = cellH * Art.ids.length + pad
const pixels = Buffer.alloc(width * height * 4)

function parse(color) {
  let m = /^#([0-9a-f]{6})$/i.exec(color)
  if (m) { const n = parseInt(m[1], 16); return [n >> 16, (n >> 8) & 255, n & 255, 1] }
  m = /^rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)$/.exec(color)
  if (!m) throw new Error("unsupported colour " + color)
  return [+m[1], +m[2], +m[3], +m[4]]
}

function fill(x, y, w, h, [r, g, b, a]) {
  for (let yy = Math.max(0, y); yy < Math.min(height, y + h); yy++)
    for (let xx = Math.max(0, x); xx < Math.min(width, x + w); xx++) {
      const i = (yy * width + xx) * 4
      pixels[i] = Math.round(pixels[i] * (1 - a) + r * a)
      pixels[i + 1] = Math.round(pixels[i + 1] * (1 - a) + g * a)
      pixels[i + 2] = Math.round(pixels[i + 2] * (1 - a) + b * a)
      pixels[i + 3] = 255
    }
}

// A canvas context with just what Art.draw uses.
const ctx = { fillStyle: "#000000", fillRect(x, y, w, h) { fill(x, y, w, h, parse(this.fillStyle)) } }

fill(0, 0, width, height, parse("#fbe3b0"))
Art.ids.forEach((id, row) => {
  poses.forEach(([name, t, progress, talking], col) => {
    Art.draw(ctx, unit, pad + col * cellW, pad + row * cellH, Art.pose(name, t, progress, talking), id)
  })
})

function crc32(buf) {
  let crc = 0xffffffff
  for (const byte of buf) {
    let c = (crc ^ byte) & 0xff
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
    crc = (crc >>> 8) ^ c
  }
  return (crc ^ 0xffffffff) >>> 0
}

function chunk(type, data) {
  const length = Buffer.alloc(4)
  length.writeUInt32BE(data.length)
  const body = Buffer.concat([Buffer.from(type), data])
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(body))
  return Buffer.concat([length, body, crc])
}

const raw = Buffer.alloc((width * 4 + 1) * height)
for (let y = 0; y < height; y++) pixels.copy(raw, y * (width * 4 + 1) + 1, y * width * 4, (y + 1) * width * 4)
const header = Buffer.alloc(13)
header.writeUInt32BE(width, 0)
header.writeUInt32BE(height, 4)
header[8] = 8
header[9] = 6

fs.writeFileSync(out, Buffer.concat([
  Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
  chunk("IHDR", header), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))
]))
console.log(`wrote ${out} (${width}x${height})`)
