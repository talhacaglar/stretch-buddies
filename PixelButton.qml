import QtQuick
import qs.Commons

// A small wooden button in the dialogue box. `primary` gets a greener
// parchment so the suggested choice stands out.
Item {
  id: root

  property string label: ""
  property bool primary: false
  property int unit: 3
  property string fontFamily: Style.font.family
  property int fontSize: Style.font.title
  signal clicked()

  readonly property bool hot: mouse.containsMouse

  implicitWidth: text.implicitWidth + frame.inset * 2 + unit * 6
  implicitHeight: text.implicitHeight + frame.inset * 2 + unit * 2

  WoodFrame {
    id: frame
    anchors.fill: parent
    unit: root.unit
    band: 1
    paper: root.primary ? (root.hot ? "#d8f0a0" : "#c6e58a") : (root.hot ? "#fff3d1" : "#fbe3b0")
    paperShade: root.primary ? "#a9cf6c" : "#efcd8c"
  }

  Text {
    id: text
    anchors.centerIn: parent
    anchors.verticalCenterOffset: mouse.pressed ? root.unit / 2 : 0
    textFormat: Text.PlainText
    text: root.label
    color: "#5b2e0e"
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    font.bold: true
  }

  scale: hot && !mouse.pressed ? 1.04 : 1
  Behavior on scale {
    enabled: !Style.reduceMotion
    NumberAnimation { duration: 90 }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
