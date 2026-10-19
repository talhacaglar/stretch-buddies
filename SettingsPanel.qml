import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import qs.Ui as Ui
import "Art.js" as Art

// Popup for the bar button: the chosen character and its countdown, quick
// actions, and the settings (break interval, snooze, stretches per break,
// character, language). Settings are saved into this widget's shell.json
// entry through the host widget, which also forwards them to the service.
//
// The base type is qualified on purpose: an unqualified `Panel` could
// resolve to a sibling file of the same name in this plugin directory.
Ui.Panel {
  id: root
  moduleName: "io.github.talhacaglar.stretch-buddies"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var host: hostWidget

  readonly property color fg: root.bar ? root.bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(fg, 1.5)
  readonly property color accent: Commons.Color.accent
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  readonly property var strings: host ? host.strings : null
  readonly property string characterId: host ? host.characterId : "rigo"
  readonly property var cast: Art.character(characterId)

  function t(key) { return strings ? strings.t(key) : "" }
  function num(n) { return strings ? strings.formatNumber(n) : String(n) }
  function minutes(n) { return strings ? strings.tn("panel.minutes", n).arg(root.num(n)) : "" }

  function statusText() {
    if (!host || !host.state) return ""
    if (host.visiting) return t("panel.here")
    if (host.paused) return t("panel.paused")
    return strings.tn("panel.nextIn", host.remainingMinutes).arg(root.num(host.remainingMinutes))
  }

  function openFromHotkey() { root.controller.show() }
  function open() { openFromHotkey() }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.openFromHotkey() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(panelContent.implicitHeight)

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onReturnRequested: if (host) { root.close(); host.stretchNow() }
      onTextKey: function(text) {
        if (!host) return
        if (text === "s") { root.close(); host.stretchNow() }
        else if (text === "p") host.togglePause()
        else if (text === "r") host.send(["reset"])
        else if (text === "+" || text === "=") host.nudgeInterval(5)
        else if (text === "-") host.nudgeInterval(-5)
      }

      Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: panelContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: panelContent
          width: scroller.width
          spacing: Style.space(14)

          // ---- Hero: the character, who it is and when it visits next.
          Item {
            width: parent.width
            height: heroSprite.height

            Rectangle {
              id: heroFrame
              x: Style.space(8)
              width: heroSprite.width + Style.space(12)
              height: heroSprite.height
              radius: Style.space(6)
              color: root.cast.portrait

              PixelSprite {
                id: heroSprite
                anchors.horizontalCenter: parent.horizontalCenter
                character: root.characterId
                unit: Math.max(2, Math.round(Style.space(3)))
                pose: host && host.visiting ? "cheer" : "idle"
                running: root.opened
              }
            }

            Column {
              anchors.left: heroFrame.right
              anchors.leftMargin: Style.space(16)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.cast.name
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
              }
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.t(root.characterId + ".tagline")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.statusText()
                color: host && host.paused ? root.dim : root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                wrapMode: Text.WordWrap
              }
            }
          }

          Flow {
            x: Style.space(8)
            width: parent.width - Style.space(16)
            spacing: Style.space(8)

            Button {
              iconText: "󰐊"
              text: root.t("panel.stretchNow")
              bordered: true
              fontFamily: root.fontFamily
              onClicked: if (host) { root.close(); host.stretchNow() }
            }
            Button {
              iconText: host && host.paused ? "󰐊" : "󰏤"
              text: root.t(host && host.paused ? "panel.resume" : "panel.pause")
              bordered: true
              fontFamily: root.fontFamily
              onClicked: if (host) host.togglePause()
            }
            Button {
              iconText: "󰑐"
              text: root.t("panel.reset")
              bordered: true
              fontFamily: root.fontFamily
              onClicked: if (host) host.send(["reset"])
            }
          }

          Divider {}

          // ---- Timing.
          Stepper {
            label: root.t("panel.interval")
            value: host ? host.intervalMinutes : 20
            display: root.minutes(value)
            step: 5
            minimum: 5
            maximum: 120
            onPicked: function(v) { if (host) host.saveSetting("intervalMinutes", v) }
          }
          Stepper {
            label: root.t("panel.snooze")
            value: host ? host.snoozeMinutes : 5
            display: root.minutes(value)
            step: 1
            minimum: 1
            maximum: 30
            onPicked: function(v) { if (host) host.saveSetting("snoozeMinutes", v) }
          }
          Stepper {
            label: root.t("panel.stretches")
            value: host ? host.exercisesPerBreak : 3
            display: root.num(value)
            step: 1
            minimum: 1
            maximum: 5
            onPicked: function(v) { if (host) host.saveSetting("exercisesPerBreak", v) }
          }

          Divider {}

          // ---- Character: one card per member of the cast.
          SectionLabel { text: root.t("panel.character").toUpperCase() }

          Row {
            x: Style.space(8)
            spacing: Style.space(10)

            Repeater {
              model: Art.ids

              Rectangle {
                id: card
                required property string modelData
                readonly property var who: Art.character(modelData)
                readonly property bool chosen: modelData === root.characterId

                width: Style.space(112)
                height: cardColumn.implicitHeight + Style.space(12)
                radius: Style.space(6)
                color: chosen ? Util.alpha(root.accent, 0.18) : cardMouse.containsMouse ? Util.alpha(root.fg, 0.08) : "transparent"
                border.width: chosen ? Math.max(1, Style.space(2)) : Math.max(1, Style.space(1))
                border.color: chosen ? root.accent : Util.alpha(root.fg, 0.2)

                Column {
                  id: cardColumn
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.top: parent.top
                  anchors.topMargin: Style.space(6)
                  spacing: Style.space(4)

                  Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: cardSprite.width + Style.space(8)
                    height: cardSprite.height
                    radius: Style.space(4)
                    color: card.who.portrait

                    PixelSprite {
                      id: cardSprite
                      anchors.horizontalCenter: parent.horizontalCenter
                      character: card.modelData
                      unit: Math.max(2, Math.round(Style.space(2)))
                      pose: card.chosen ? "talk" : "idle"
                      running: root.opened && (card.chosen || cardMouse.containsMouse)
                    }
                  }

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: card.who.name
                    color: card.chosen ? root.accent : root.fg
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: card.chosen
                  }
                }

                MouseArea {
                  id: cardMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (host) host.saveSetting("character", card.modelData)
                }
              }
            }
          }

          Divider {}

          // ---- Language: Omarchy's, or one of the shipped catalogs.
          Item {
            width: parent.width
            height: languagePicker.implicitHeight

            SectionLabel {
              anchors.verticalCenter: parent.verticalCenter
              text: root.t("panel.language").toUpperCase()
            }

            Dropdown {
              id: languagePicker
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              width: Style.space(200)
              showLabel: false
              fontFamily: root.fontFamily
              value: host ? host.languageSetting : "auto"
              options: [{ value: "auto", label: root.t("panel.languageAuto") }].concat(root.strings ? root.strings.languages : [])
              onChanged: function(value) { if (host) host.saveSetting("language", value) }
            }
          }
        }
      }
    }
  }

  component Divider: Rectangle {
    width: parent ? parent.width : 0
    height: Style.spacing.hairline
    color: root.fg
    opacity: 0.12
  }

  component SectionLabel: Text {
    x: Style.space(8)
    textFormat: Text.PlainText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: 1
  }

  // A labelled "− value +" row.
  component Stepper: Item {
    id: stepper
    property string label: ""
    property string display: ""
    property int value: 0
    property int step: 1
    property int minimum: 0
    property int maximum: 100
    signal picked(int value)

    width: parent ? parent.width : 0
    height: minus.implicitHeight

    Text {
      x: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: stepper.label
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Row {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      Button {
        id: minus
        text: "−"
        bordered: true
        fontFamily: root.fontFamily
        opacity: stepper.value > stepper.minimum ? 1 : 0.4
        onClicked: if (stepper.value > stepper.minimum)
          stepper.picked(Math.max(stepper.minimum, stepper.value - stepper.step))
      }
      Text {
        width: Style.space(64)
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: stepper.display
        color: root.fg
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }
      Button {
        text: "+"
        bordered: true
        fontFamily: root.fontFamily
        opacity: stepper.value < stepper.maximum ? 1 : 0.4
        onClicked: if (stepper.value < stepper.maximum)
          stepper.picked(Math.min(stepper.maximum, stepper.value + stepper.step))
      }
    }
  }
}
