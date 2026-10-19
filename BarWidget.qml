import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "Art.js" as Art

// The bar button: the chosen character's pixel head and the minutes until
// it visits. Click opens the settings panel, right click pauses or resumes,
// middle click stretches now, and scrolling changes the interval.
//
// Replacement bars give widgets no access to plugin services, so this reads
// the state file the service keeps in $XDG_RUNTIME_DIR and sends commands
// over IPC. Between writes the countdown is computed locally from `dueAtMs`.
//
// The base type is qualified on purpose: this file is itself named
// BarWidget.qml, so an unqualified `BarWidget` would resolve to this file.
Ui.BarWidget {
  id: root
  moduleName: "io.github.talhacaglar.stretch-buddies"

  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + Quickshell.env("UID"))
  readonly property double loadStamp: Date.now()

  // Saved values win once shell.json catches up; until then the last pick
  // shows at once.
  property var overrides: ({})
  function value(name, fallback) {
    return overrides[name] !== undefined ? overrides[name] : setting(name, fallback)
  }
  function intSetting(name, fallback, lo, hi) {
    var n = parseInt(value(name, fallback), 10)
    return isNaN(n) ? fallback : Math.max(lo, Math.min(hi, n))
  }

  readonly property int intervalMinutes: intSetting("intervalMinutes", 20, 5, 120)
  readonly property int snoozeMinutes: intSetting("snoozeMinutes", 5, 1, 30)
  readonly property int exercisesPerBreak: intSetting("exercisesPerBreak", 3, 1, 5)
  readonly property string characterId: {
    var id = String(value("character", "rigo"))
    return Art.ids.indexOf(id) !== -1 ? id : "rigo"
  }
  readonly property string languageSetting: {
    var code = String(value("language", "auto"))
    return code === "auto" || /^[a-z]{2,3}(-[A-Za-z]{2})?$/.test(code) ? code : "auto"
  }
  readonly property string characterName: Art.character(characterId).name

  readonly property Catalog strings: Catalog { language: root.languageSetting }

  property var state: null
  property double nowMs: Date.now()

  readonly property bool visiting: state ? state.phase !== "waiting" : false
  readonly property bool paused: state ? state.paused === true : false
  readonly property int remainingMinutes: {
    if (!state) return 0
    var left = paused ? Number(state.pausedLeftMs) : Number(state.dueAtMs) - nowMs
    return Math.ceil(Math.max(0, left || 0) / 60000)
  }

  // Only fixed words and validated values reach the command line.
  function send(args) {
    Quickshell.execDetached(["bash", "-lc", 'exec omarchy-shell -q io.github.talhacaglar.stretch-buddies "$@"', "bash"].concat(args))
  }

  function pushSettings() {
    send(["configure", String(intervalMinutes), String(snoozeMinutes), String(exercisesPerBreak)])
    send(["character", characterId])
    send(["language", languageSetting])
  }

  // Persist one setting into this widget's shell.json entry.
  function saveSetting(name, v) {
    var next = {}
    for (var k in overrides) next[k] = overrides[k]
    next[name] = v
    overrides = next

    var entry = {}
    var current = settings || {}
    for (var key in current) if (key !== "id") entry[key] = current[key]
    for (var o in next) entry[o] = next[o]
    var api = bar ? bar.shell : null
    if (api && typeof api.updateEntryInline === "function") api.updateEntryInline("io.github.talhacaglar.stretch-buddies", entry)
  }

  function nudgeInterval(delta) {
    saveSetting("intervalMinutes", Math.max(5, Math.min(120, intervalMinutes + delta)))
  }

  function stretchNow() { send(["now"]) }
  function togglePause() { send([paused ? "resume" : "pause"]) }

  function readState(raw) {
    try {
      var parsed = JSON.parse(String(raw || "").trim() || "null")
      if (parsed && typeof parsed === "object") {
        state = parsed
        nowMs = Date.now()
      }
    } catch (e) {
      // A half-written file; the next change brings a whole one.
    }
  }

  function label() {
    if (!state || visiting || vertical) return ""
    return paused ? "‖" : strings.t("bar.minutes").arg(strings.formatNumber(remainingMinutes))
  }

  function tooltip() {
    var when
    if (!state) when = strings.t("tooltip.waking").arg(characterName)
    else if (visiting) when = strings.t("tooltip.here").arg(characterName)
    else if (paused) when = strings.t("tooltip.paused").arg(characterName)
    else when = strings.tn("tooltip.coming", remainingMinutes).arg(characterName).arg(strings.formatNumber(remainingMinutes))
    return when + "\n" + strings.t("tooltip.hints")
  }

  // Shape contract for shell summon/hide/toggle routing: the bar talks to
  // this root, which forwards to the panel.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: button.implicitWidth * 0.55

  function open() { if (panelLoader.item) panelLoader.item.openFromHotkey() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = button
    target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  // Drop overrides the saved settings now agree with. Deferred: settings
  // can change while a binding is reading them.
  function pruneOverrides() {
    var next = {}
    var changed = false
    for (var k in overrides) {
      if (String(setting(k, "")) !== String(overrides[k])) next[k] = overrides[k]
      else changed = true
    }
    if (changed) overrides = next
  }

  onSettingsChanged: {
    injectPanel()
    Qt.callLater(pruneOverrides)
  }
  onIntervalMinutesChanged: pushSettings()
  onSnoozeMinutesChanged: pushSettings()
  onExercisesPerBreakChanged: pushSettings()
  onCharacterIdChanged: pushSettings()
  onLanguageSettingChanged: pushSettings()
  Component.onCompleted: pushSettings()

  FileView {
    id: stateFile
    path: root.runtimeDir + "/stretch-buddies.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.readState(text())
    onFileChanged: reload()
  }

  // Minute display between writes; also retries until the service has
  // written its first state.
  Timer {
    interval: root.state ? 10000 : 2000
    repeat: true
    running: true
    onTriggered: {
      root.nowMs = Date.now()
      if (!root.state) stateFile.reload()
    }
  }

  Loader {
    id: panelLoader
    active: true
    // The query defeats the engine's per-URL component cache, so a plugin
    // hot-reload picks up the new panel without a restart.
    source: Qt.resolvedUrl("SettingsPanel.qml") + "?v=" + root.loadStamp
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // The button is built from plain items rather than BarIconButton, whose
  // label support only exists on newer shells. It registers as a click
  // target and uses the bar's shared tooltip, as WidgetButton does.
  Item {
    id: button

    readonly property color fg: root.bar && root.bar.barForeground ? root.bar.barForeground : Commons.Color.foreground
    readonly property color urgent: root.bar && root.bar.urgent ? root.bar.urgent : Commons.Color.urgent
    readonly property int unit: Math.max(1, Math.floor((root.barSize - Style.space(10)) / Art.ICON_H))
    property var registeredBar: null

    function syncClickRegistration() {
      if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(button)
      registeredBar = root.bar
      if (registeredBar && registeredBar.registerClickTarget) registeredBar.registerClickTarget(button)
    }

    function hideTooltip() {
      if (root.bar && root.bar.hideTooltip) root.bar.hideTooltip(button)
    }

    anchors.fill: parent
    implicitWidth: root.vertical ? root.barSize : content.width + Style.space(14)
    implicitHeight: root.vertical ? content.height + Style.space(12) : root.barSize

    Component.onCompleted: syncClickRegistration()
    Component.onDestruction: {
      hideTooltip()
      if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(button)
    }
    Connections {
      target: root
      function onBarChanged() { button.syncClickRegistration() }
    }

    Rectangle {
      anchors.centerIn: parent
      width: parent.width - Style.space(2)
      height: Math.min(parent.height, root.barSize) - Style.space(6)
      radius: Style.space(4)
      color: root.visiting ? Util.alpha(button.urgent, 0.28)
        : mouse.containsMouse ? Util.alpha(button.fg, 0.10) : "transparent"
    }

    Grid {
      id: content
      anchors.centerIn: parent
      columns: root.vertical ? 1 : 2
      spacing: Style.space(5)
      verticalItemAlignment: Grid.AlignVCenter
      horizontalItemAlignment: Grid.AlignHCenter
      opacity: root.paused ? 0.55 : 1

      Canvas {
        id: icon
        readonly property string who: root.characterId
        width: Art.ICON_W * button.unit
        height: Art.ICON_H * button.unit
        antialiasing: false
        onWhoChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          Art.drawIcon(ctx, button.unit, 0, 0, who)
        }
      }

      Text {
        id: label
        visible: text !== ""
        textFormat: Text.PlainText
        text: root.label()
        color: button.fg
        font.family: root.bar && root.bar.fontFamily ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: if (root.bar && root.bar.showTooltip) root.bar.showTooltip(button, root.tooltip())
      onExited: button.hideTooltip()
      onClicked: function(event) {
        button.hideTooltip()
        if (event.button === Qt.RightButton) root.togglePause()
        else if (event.button === Qt.MiddleButton) root.stretchNow()
        else root.toggle()
      }
      onWheel: function(wheel) { root.nudgeInterval(wheel.angleDelta.y > 0 ? 5 : -5) }
    }
  }
}
