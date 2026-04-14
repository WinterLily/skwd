import ".."
import QtQuick

// Shared parallelogram panel for any bar corner.
// Children are placed in the internal Row via the default property alias.
Item {
    id: root

    // "top-left" | "top-right" | "bottom-left" | "bottom-right"
    property string corner: "top-right"
    property real diagSlant: 28
    property real spacing: 14
    property bool accentEdges: Config.accentEdges
    // Children placed here become items in the content row
    default property alias content: row.data

    width: row.implicitWidth + diagSlant + 24

    Canvas {
        id: bg

        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var s = root.diagSlant;
            // Fill shape
            ctx.beginPath();
            switch (root.corner) {
            case "top-left":
                // Top full-width, bottom-right corner cut — slant on the right
                ctx.moveTo(0, 0);
                ctx.lineTo(width, 0);
                ctx.lineTo(width - s, height);
                ctx.lineTo(0, height);
                break;
            case "top-right":
                // Top full-width, bottom-left corner cut — slant on the left
                ctx.moveTo(0, 0);
                ctx.lineTo(width, 0);
                ctx.lineTo(width, height);
                ctx.lineTo(s, height);
                break;
            case "bottom-left":
                // Bottom full-width, top-right corner cut — slant on the right
                ctx.moveTo(0, 0);
                ctx.lineTo(width - s, 0);
                ctx.lineTo(width, height);
                ctx.lineTo(0, height);
                break;
            default:
                // bottom-right
                // Bottom full-width, top-left corner cut — slant on the left
                ctx.moveTo(s, 0);
                ctx.lineTo(width, 0);
                ctx.lineTo(width, height);
                ctx.lineTo(0, height);
                break;
            }
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 1);
            ctx.fill();
            // Accent edge — traces the two exposed (non-screen-edge) sides
            if (root.accentEdges) {
                ctx.beginPath();
                switch (root.corner) {
                case "top-left":
                    // Bottom edge + right slant (bottom-right diagonal)
                    ctx.moveTo(0, height);
                    ctx.lineTo(width - s, height);
                    ctx.lineTo(width, 0);
                    break;
                case "top-right":
                    // Left slant + bottom edge (bottom-left diagonal)
                    ctx.moveTo(0, 0);
                    ctx.lineTo(s, height);
                    ctx.lineTo(width, height);
                    break;
                case "bottom-left":
                    // Top edge + right slant (top-right diagonal)
                    ctx.moveTo(0, 0);
                    ctx.lineTo(width - s, 0);
                    ctx.lineTo(width, height);
                    break;
                default:
                    // bottom-right
                    // Left slant + top edge (top-left diagonal)
                    ctx.moveTo(0, height);
                    ctx.lineTo(s, 0);
                    ctx.lineTo(width, 0);
                    break;
                }
                ctx.strokeStyle = Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 1);
                ctx.lineWidth = 1.5;
                ctx.lineJoin = "miter";
                ctx.stroke();
            }
        }

        Connections {
            function onSurfaceChanged() {
                bg.requestPaint();
            }

            function onPrimaryChanged() {
                bg.requestPaint();
            }

            target: Colors
        }

        Connections {
            function onAccentEdgesChanged() {
                bg.requestPaint();
            }

            function onCornerChanged() {
                bg.requestPaint();
            }

            target: root
        }

    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        // Shift content toward the visual center of the parallelogram
        anchors.horizontalCenterOffset: (root.corner === "top-right" || root.corner === "bottom-right") ? root.diagSlant / 2 : -root.diagSlant / 2
        spacing: root.spacing
    }

}
