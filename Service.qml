import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "Exercises.js" as Exercises
import "Art.js" as Art

// Stretch Buddies: after `intervalMinutes` of sitting the chosen character
// (Rigo, Mochi or Porcini) pops up at the bottom of the screen in a
// Stardew-style dialogue box and leads a short round of neck and back
// stretches.
//
// A service, so the countdown and the dialogue exist once however many bars
// show the widget. Replacement bars hand widgets no service access, so the
// widget never touches this object: it watches the state file written below
// and sends commands over IPC (`omarchy-shell io.github.talhacaglar.stretch-buddies now`).
//
// Phases: waiting (counting down), calling (the character asks), exercising,
// bye (a closing line, then back to waiting). Lines are kept as catalog keys
// so a language switch re-renders whatever is on screen.
Item {
  id: root

  property var shell: null

  // Tuned from the widget's entry in shell.json (see applySettings).
  property int intervalMinutes: 20
  property int snoozeMinutes: 5
  property int exercisesPerBreak: 3
  property string character: "rigo"
  property string language: "auto"
  // Away this long (no input) and the sitting clock starts over.
  property int awayMinutes: 5
  // An unanswered visit passes on its own after this long. Hovering the box
  // holds the countdown, so it never vanishes while being read or clicked.
  property int answerSeconds: 15
  readonly property bool dialogHovered: dialog.hovered

  readonly property Catalog catalog: Catalog { language: root.language }

  property string phase: "waiting"
  property bool paused: false
  property bool snoozed: false
  property double cycleStartMs: Date.now()
  property double dueAtMs: cycleStartMs + intervalMinutes * 60000
  property double pausedLeftMs: 0
  property double sittingSinceMs: Date.now()
  property double nowMs: Date.now()
  property double lastTickMs: Date.now()
  property double callEndsAtMs: 0

  property var bag: []
  property var round: []
  property int step: 0
  property double stepStartMs: 0
  property string lineKey: ""
  property int lineCount: -1
  property bool cheering: false

  readonly property var current: phase === "exercising" && step < round.length ? round[step] : null
  readonly property real stepMs: current ? current.seconds * 1000 : 1
  readonly property real stepProgress: current ? Math.min(1, Math.max(0, (nowMs - stepStartMs) / stepMs)) : 0
  readonly property int stepSecondsLeft: current ? Math.max(0, Math.ceil((stepMs - (nowMs - stepStartMs)) / 1000)) : 0
  readonly property int callSecondsLeft: phase === "calling" ? Math.max(0, Math.ceil((callEndsAtMs - nowMs) / 1000)) : 0
  readonly property real remainingMs: paused ? pausedLeftMs : Math.max(0, dueAtMs - nowMs)
  readonly property int remainingMinutes: Math.ceil(remainingMs / 60000)
  readonly property string barPosition: shell && shell.barConfig && shell.barConfig.position
    ? String(shell.barConfig.position) : "top"

  // What the bar widget needs, mirrored to $XDG_RUNTIME_DIR/stretch-buddies.json.
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + Quickshell.env("UID"))
  readonly property string stateJson: JSON.stringify({
    phase: phase, paused: paused, dueAtMs: dueAtMs, pausedLeftMs: pausedLeftMs
  })
  onStateJsonChanged: Qt.callLater(writeState)
  Component.onCompleted: writeState()

  function writeState() {
    stateFile.setText(stateJson + "\n")
  }

  function minutesSitting() {
    return Math.max(1, Math.round((Date.now() - sittingSinceMs) / 60000))
  }

  // Start the countdown over from now.
  function restart() {
    nowMs = Date.now()
    cycleStartMs = nowMs
    dueAtMs = nowMs + intervalMinutes * 60000
    snoozed = false
  }

  // `scheduled` is a visit the timer made (or `visit` over IPC); otherwise
  // the user called early and gets an eager line instead of a greeting.
  function callNow(scheduled) {
    if (phase !== "waiting") return
    nowMs = Date.now()
    cheering = false
    var sat = minutesSitting()
    if (scheduled) setLine(Exercises.line(character, "greeting", Math.max(sat, intervalMinutes)))
    else setLine(Exercises.line(character, sat < intervalMinutes ? "eager" : "greeting", sat))
    callEndsAtMs = nowMs + answerSeconds * 1000
    phase = "calling"
  }

  function start() {
    var picked = Exercises.draw(bag, Math.max(1, exercisesPerBreak))
    bag = picked.bag
    round = picked.round
    step = 0
    nowMs = Date.now()
    stepStartMs = nowMs
    phase = round.length ? "exercising" : "waiting"
  }

  function next() {
    if (phase !== "exercising") return
    if (step + 1 >= round.length) {
      finish()
      return
    }
    step += 1
    nowMs = Date.now()
    stepStartMs = nowMs
  }

  function finish() {
    sittingSinceMs = Date.now()
    restart()
    say(Exercises.line(character, "cheer", intervalMinutes), true, 9000)
  }

  function snooze() {
    nowMs = Date.now()
    dueAtMs = nowMs + snoozeMinutes * 60000
    snoozed = true
    say(Exercises.line(character, "snoozed", snoozeMinutes), false, 4500)
  }

  function skip() {
    restart()
    say(Exercises.line(character, "skipped", 0), false, 4500)
  }

  // Nobody answered: pass on this break quietly and count down a full
  // interval again, the same as Skip but without a closing line.
  function autoSkip() {
    restart()
    dismiss()
  }

  function setLine(line) {
    lineKey = line.key
    lineCount = line.count
  }

  // A closing line, then the character leaves on its own after `holdMs`.
  function say(line, cheer, holdMs) {
    cheering = cheer
    setLine(line)
    phase = "bye"
    byeTimer.interval = holdMs
    byeTimer.restart()
  }

  function dismiss() {
    byeTimer.stop()
    phase = "waiting"
    round = []
  }

  function setPaused(value) {
    if (value === paused) return
    nowMs = Date.now()
    if (value) {
      pausedLeftMs = Math.max(0, dueAtMs - nowMs)
    } else {
      dueAtMs = nowMs + pausedLeftMs
    }
    paused = value
  }

  function status() {
    return JSON.stringify({
      phase: phase,
      paused: paused,
      remainingMinutes: remainingMinutes,
      intervalMinutes: intervalMinutes,
      character: character,
      language: catalog.code,
      exercise: current ? current.id : ""
    })
  }

  // Settings live on this plugin's widget entry in shell.json. The service
  // reads them from there itself, so they apply after a shell restart (or an
  // `omarchy bar set`) whichever part of the shell happens to load first.
  readonly property string pluginId: "io.github.talhacaglar.stretch-buddies"

  function settingsEntry(config) {
    function find(list) {
      if (!Array.isArray(list)) return null
      for (var i = 0; i < list.length; i++)
        if (list[i] && list[i].id === root.pluginId) return list[i]
      return null
    }
    var layout = config && config.bar && config.bar.layout
    if (layout && typeof layout === "object") {
      for (var section in layout) {
        var entry = find(layout[section])
        if (entry) return entry
      }
    }
    return find(config && config.plugins) || ({})
  }

  function applySettings(raw) {
    var config
    try {
      config = JSON.parse(String(raw || "")) || ({})
    } catch (e) {
      return  // mid-write or hand-edited; the next change brings a whole file
    }
    var entry = settingsEntry(config)
    function number(key, fallback, lo, hi) {
      var n = parseInt(entry[key], 10)
      return isNaN(n) ? fallback : Math.max(lo, Math.min(hi, n))
    }
    configure(number("intervalMinutes", 20, 5, 120), number("snoozeMinutes", 5, 1, 30),
      number("exercisesPerBreak", 3, 1, 5))
    setCharacter(entry.character || "rigo")
    setLanguage(entry.language || "auto")
  }

  function configure(interval, snooze, count) {
    if (interval > 0) intervalMinutes = Math.min(240, interval)
    if (snooze > 0) snoozeMinutes = Math.min(60, snooze)
    if (count > 0) exercisesPerBreak = Math.min(Exercises.all.length, count)
  }

  function setCharacter(id) {
    if (Art.ids.indexOf(String(id)) !== -1) character = String(id)
  }

  function setLanguage(code) {
    var value = String(code || "auto")
    if (value === "auto" || /^[a-z]{2,3}(-[A-Za-z]{2})?$/.test(value)) language = value
  }

  onIntervalMinutesChanged: {
    if (phase === "waiting" && !paused && !snoozed) dueAtMs = cycleStartMs + intervalMinutes * 60000
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applySettings(text())
  }

  FileView {
    id: stateFile
    path: root.runtimeDir + "/stretch-buddies.json"
    watchChanges: false
    atomicWrites: true
    printErrors: false
  }

  // Coarse while counting down, fine while the dialogue is up.
  Timer {
    interval: root.phase === "waiting" ? 5000 : 200
    repeat: true
    running: true
    onTriggered: {
      var now = Date.now()
      var elapsed = now - root.lastTickMs
      // A long gap means the machine slept: that was not sitting.
      if (now - root.lastTickMs > 120000 && root.phase === "waiting") {
        root.sittingSinceMs = now
        root.restart()
      }
      root.lastTickMs = now
      root.nowMs = now
      if (root.phase === "waiting" && !root.paused && now >= root.dueAtMs) root.callNow(true)
      else if (root.phase === "exercising" && now - root.stepStartMs >= root.stepMs) root.next()
      else if (root.phase === "calling") {
        if (root.dialogHovered) root.callEndsAtMs += elapsed
        else if (now >= root.callEndsAtMs) root.autoSkip()
      }
    }
  }

  Timer {
    id: byeTimer
    onTriggered: root.dismiss()
  }

  // Coming back after a while away starts the sitting clock over. Idle
  // inhibitors (a playing video) still count as sitting.
  IdleMonitor {
    enabled: root.awayMinutes > 0
    timeout: Math.max(60, root.awayMinutes * 60)
    respectInhibitors: true
    onIsIdleChanged: {
      if (isIdle) {
        if (root.phase === "calling") root.dismiss()
        return
      }
      if (root.phase !== "waiting") return
      root.sittingSinceMs = Date.now()
      root.restart()
    }
  }

  // A full-screen overlay on the focused monitor, built from plain
  // Quickshell types so it works on every Omarchy 4 shell. It never takes
  // keyboard focus, and its mask lets clicks through everywhere but the box.
  PanelWindow {
    id: window

    readonly property bool shown: root.phase !== "waiting"
    property var targetScreen: null

    function focusedScreen() {
      var monitor = Hyprland.focusedMonitor
      var name = monitor ? String(monitor.name || "") : ""
      for (var i = 0; i < Quickshell.screens.length; i++)
        if (Quickshell.screens[i].name === name) return Quickshell.screens[i]
      return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    onShownChanged: if (shown) targetScreen = focusedScreen()

    visible: shown && !!targetScreen
    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "stretch-buddies"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: dialog }

    // A monitor unplugged mid-visit: move to whichever one has focus now.
    Connections {
      target: Quickshell
      function onScreensChanged() {
        if (window.shown && Quickshell.screens.indexOf(window.targetScreen) < 0)
          window.targetScreen = window.focusedScreen()
      }
    }

    DialogBox {
      id: dialog
      service: root
      width: Math.min(Style.space(820), window.width - Style.space(64))
      height: implicitHeight
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(root.barPosition === "bottom" ? 72 : 40)
    }
  }

  // A plain IpcHandler: omarchy-shell reaches it through `qs ipc` on every
  // Omarchy 4 shell (newer shells try their own socket first, then fall back).
  IpcHandler {
    target: "io.github.talhacaglar.stretch-buddies"

    function now(): void { root.callNow(false) }
    function visit(): void { root.callNow(true) }
    function start(): void {
      if (root.phase === "waiting") root.callNow(false)
      if (root.phase === "calling") root.start()
    }
    function pause(): void { root.setPaused(true) }
    function resume(): void { root.setPaused(false) }
    function toggle(): void { root.setPaused(!root.paused) }
    function reset(): void {
      root.sittingSinceMs = Date.now()
      root.restart()
    }
    function next(): void { root.next() }
    function dismiss(): void { root.dismiss() }
    function status(): string { return root.status() }
  }
}
