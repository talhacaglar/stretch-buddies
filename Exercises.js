.pragma library

// The stretches and the shape of what each character says around them.
// All wording lives in i18n/<code>.json; this only names the keys.
//
// Each exercise runs `seconds` long and names the Art pose that acts it out.
// Two-sided moves have a `second` line that replaces the text halfway.
var all = [
  { id: "neckTilt", pose: "neckTilt", seconds: 20, second: true },
  { id: "chinTuck", pose: "chinTuck", seconds: 15, second: false },
  { id: "shoulderRoll", pose: "shoulderRoll", seconds: 15, second: false },
  { id: "scapula", pose: "scapula", seconds: 15, second: false },
  { id: "twist", pose: "twist", seconds: 20, second: true },
  { id: "reachUp", pose: "reachUp", seconds: 12, second: false },
  { id: "chestOpen", pose: "chestOpen", seconds: 12, second: false }
]

// How many numbered variants each kind of line has, per character, and
// which of them count minutes (those are plural entries taking %1).
var variants = { greeting: 3, eager: 2, cheer: 3 }
var counted = { "greeting.1": true, "cheer.1": true, "snoozed": true }

// A line for `character` of `kind`, as { key, count }; count is -1 when the
// line takes no number.
function line(character, kind, minutes) {
  var n = variants[kind] || 0
  var suffix = n ? kind + "." + (1 + Math.floor(Math.random() * n)) : kind
  return { key: character + "." + suffix, count: counted[suffix] ? minutes : -1 }
}

function byId(id) {
  for (var i = 0; i < all.length; i++) if (all[i].id === id) return all[i]
  return null
}

function shuffled() {
  var ids = all.map(function(e) { return e.id })
  for (var i = ids.length - 1; i > 0; i--) {
    var j = Math.floor(Math.random() * (i + 1))
    var tmp = ids[i]; ids[i] = ids[j]; ids[j] = tmp
  }
  return ids
}

// Draw `count` exercises from a shuffle bag so every stretch comes up before
// any repeats. Returns the round and the bag left over for next time.
function draw(bag, count) {
  var left = (bag || []).slice()
  var round = []
  while (round.length < count) {
    if (left.length === 0) left = shuffled().filter(function(id) {
      return round.every(function(e) { return e.id !== id })
    })
    if (left.length === 0) break
    var exercise = byId(left.shift())
    if (exercise) round.push(exercise)
  }
  return { round: round, bag: left }
}
