import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Art.js" as Art

// The Stardew-style dialogue box: what the character says on the left, its
// portrait and name plate on the right, and below the text either the
// choices or the stretch timer. All state lives in the service;
// this only shows it, in the service catalog's language.
Item {
  id: root

  property var service: null

  readonly property int u: Math.max(2, Math.round(Style.space(3)))
  readonly property color ink: "#5b2e0e"
  readonly property color inkSoft: "#8a5a2b"
  readonly property string fontFamily: Style.font.family

  readonly property var catalog: service ? service.catalog : null
  readonly property var cast: Art.character(service ? service.character : "rigo")
  readonly property string phase: service ? service.phase : "waiting"
  readonly property var exercise: service ? service.current : null
  readonly property real stepProgress: service ? service.stepProgress : 0
  readonly property string message: {
    if (!service || !catalog) return ""
    if (exercise)
      return catalog.t("exercise." + exercise.id + (exercise.second && stepProgress >= 0.5 ? ".second" : ".text"))
    if (!service.lineKey) return ""
    if (service.lineCount < 0) return catalog.t(service.lineKey)
    return catalog.tn(service.lineKey, service.lineCount).arg(Commons.I18n.formatNumber(service.lineCount))
  }

  function t(key) { return catalog ? catalog.t(key) : "" }

  // Typewriter: reveal the message a letter at a time; a click shows it all.
  property int revealed: 0
  readonly property bool typing: revealed < message.length
  onMessageChanged: revealed = Style.reduceMotion ? message.length : 0

  // Slide up and fade in each time the character appears.
  property real enter: 0
  readonly property bool active: phase !== "waiting"
  onActiveChanged: {
    if (!active) return
    enter = 0
    enterAnim.restart()
  }
  NumberAnimation on enter {
    id: enterAnim
    running: false
    from: 0
    to: 1
    duration: Style.duration(260)
    easing.type: Easing.OutBack
  }
  opacity: Math.min(1, enter * 1.6)
  transform: Translate { y: (1 - root.enter) * root.u * 10 }

  implicitHeight: frame.inset * 2 + u * 4 + portrait.height + u * 2 + plate.height

  Timer {
    interval: 24
    repeat: true
    running: root.typing && root.visible
    onTriggered: root.revealed = Math.min(root.message.length, root.revealed + 1)
  }

  WoodFrame {
    id: frame
    anchors.fill: parent
    unit: root.u
  }

  Item {
    id: content
    anchors.fill: parent
    anchors.margins: frame.inset + root.u * 2

    // ---- Portrait and name plate.
    Column {
      id: portraitColumn
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: root.u * 2

      Rectangle {
        id: portrait
        width: sprite.width + root.u * 4
        height: sprite.height + root.u * 4
        color: root.cast.portrait
        border.color: "#c98f4f"
        border.width: root.u

        PixelSprite {
          id: sprite
          anchors.centerIn: parent
          unit: root.u + 1
          character: root.cast.id
          running: root.visible && root.active
          pose: root.exercise ? root.exercise.pose : (service && service.cheering ? "cheer" : "talk")
          progress: root.stepProgress
          talking: root.typing
        }
      }

      Item {
        id: plate
        width: portrait.width
        height: plateText.implicitHeight + plateFrame.inset * 2 + root.u * 2

        WoodFrame {
          id: plateFrame
          anchors.fill: parent
          unit: root.u
          band: 1
        }

        Text {
          id: plateText
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: root.cast.name
          color: root.ink
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading + 2
          font.bold: true
        }
      }
    }

    // Wooden divider between the text and the portrait.
    Rectangle {
      id: divider
      anchors.right: portraitColumn.left
      anchors.rightMargin: root.u * 4
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: root.u * 3
      color: "#d27b33"
      border.color: "#6b3416"
      border.width: root.u
    }

    // ---- What the character says.
    Item {
      id: textPane
      anchors.left: parent.left
      anchors.right: divider.left
      anchors.rightMargin: root.u * 4
      anchors.top: parent.top
      anchors.bottom: parent.bottom

      MouseArea {
        anchors.fill: parent
        onClicked: {
          if (root.typing) root.revealed = root.message.length
          else if (root.phase === "bye" && service) service.dismiss()
        }
      }

      Item {
        id: header
        width: parent.width
        height: root.exercise ? heading.implicitHeight + root.u * 2 : 0
        visible: root.exercise !== null

        Text {
          id: heading
          anchors.left: parent.left
          anchors.right: pips.left
          anchors.rightMargin: root.u * 3
          textFormat: Text.PlainText
          text: root.exercise ? root.t("exercise." + root.exercise.id + ".title") : ""
          color: root.ink
          elide: Text.ElideRight
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading + 4
          font.bold: true
        }

        // One pip per stretch in the round; done and current are filled.
        Row {
          id: pips
          anchors.right: parent.right
          anchors.verticalCenter: heading.verticalCenter
          spacing: root.u * 2

          Repeater {
            model: service ? service.round.length : 0

            Rectangle {
              required property int index
              width: root.u * 3
              height: width
              color: service && index <= service.step ? root.ink : "transparent"
              border.color: root.ink
              border.width: Math.max(1, root.u / 2)
            }
          }
        }
      }

      Text {
        id: body
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        textFormat: Text.PlainText
        text: root.message.substring(0, root.revealed)
        wrapMode: Text.WordWrap
        color: root.ink
        lineHeight: 1.15
        font.family: root.fontFamily
        font.pixelSize: Style.font.title + 4
      }

      // ---- Choices when the character first calls.
      Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        spacing: root.u * 3
        visible: root.phase === "calling"

        PixelButton {
          label: root.t("choice.start")
          primary: true
          unit: root.u
          onClicked: if (service) service.start()
        }
        PixelButton {
          label: service && root.catalog
            ? root.catalog.tn("choice.snooze", service.snoozeMinutes).arg(Commons.I18n.formatNumber(service.snoozeMinutes)) : ""
          unit: root.u
          onClicked: if (service) service.snooze()
        }
        PixelButton {
          label: root.t("choice.skip")
          unit: root.u
          onClicked: if (service) service.skip()
        }
      }

      // ---- Stretch timer: an energy-bar style countdown and a skip.
      Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: nextButton.implicitHeight
        visible: root.phase === "exercising"

        Rectangle {
          id: track
          anchors.left: parent.left
          anchors.right: secondsLeft.left
          anchors.rightMargin: root.u * 3
          anchors.verticalCenter: parent.verticalCenter
          height: root.u * 5
          color: "#6b3416"
          border.color: "#3b1d0c"
          border.width: root.u

          Rectangle {
            x: root.u
            y: root.u
            height: parent.height - root.u * 2
            width: Math.max(0, (parent.width - root.u * 2) * (1 - root.stepProgress))
            color: "#5fb83a"

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              height: root.u
              color: "#8be05a"
            }

            Behavior on width {
              enabled: !Style.reduceMotion
              NumberAnimation { duration: 260 }
            }
          }
        }

        Text {
          id: secondsLeft
          anchors.right: nextButton.left
          anchors.rightMargin: root.u * 3
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: service ? root.t("unit.seconds").arg(Commons.I18n.formatNumber(service.stepSecondsLeft)) : ""
          color: root.inkSoft
          font.family: root.fontFamily
          font.pixelSize: Style.font.title + 2
          font.bold: true
        }

        PixelButton {
          id: nextButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          label: root.t(service && service.step + 1 >= service.round.length ? "button.finish" : "button.next")
          unit: root.u
          onClicked: if (service) service.next()
        }
      }

      // Stardew's "click to continue" arrow once the character has said its piece.
      Text {
        id: arrow
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: bounce.offset
        visible: root.phase === "bye" && !root.typing
        textFormat: Text.PlainText
        text: "▼"
        color: "#c0582a"
        font.pixelSize: Style.font.heading + 2

        QtObject {
          id: bounce
          property real offset: 0
        }

        SequentialAnimation {
          running: arrow.visible && !Style.reduceMotion
          loops: Animation.Infinite
          NumberAnimation { target: bounce; property: "offset"; to: root.u * 2; duration: 260; easing.type: Easing.OutQuad }
          NumberAnimation { target: bounce; property: "offset"; to: 0; duration: 260; easing.type: Easing.InQuad }
        }
      }
    }
  }
}
