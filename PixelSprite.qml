import QtQuick
import "Art.js" as Art

// A character on a Canvas, `unit` screen pixels per art pixel, animated
// while `running`. The pose and its progress come from the caller.
Canvas {
  id: root

  property string character: "rigo"
  property int unit: 4
  property string pose: "idle"
  property real progress: 0
  property bool talking: false
  property bool running: visible
  property double startMs: Date.now()
  property real t: 0

  implicitWidth: Art.W * unit
  implicitHeight: Art.H * unit
  antialiasing: false
  renderStrategy: Canvas.Cooperative

  onPoseChanged: {
    startMs = Date.now()
    t = 0
    requestPaint()
  }
  onProgressChanged: requestPaint()
  onTalkingChanged: requestPaint()
  onUnitChanged: requestPaint()
  onCharacterChanged: requestPaint()

  Timer {
    interval: 100
    repeat: true
    running: root.running
    onTriggered: {
      root.t = (Date.now() - root.startMs) / 1000
      root.requestPaint()
    }
  }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    Art.draw(ctx, unit, 0, 0, Art.pose(pose, t, progress, talking), character)
  }
}
