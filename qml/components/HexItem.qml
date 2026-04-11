// A flat-top regular hexagon with:
//   - A built-in clip mask (expose via `mask` for content layers)
//   - A selection-aware border outline
//   - An accent rim along the bottom-left + bottom edges
//   - Hex-accurate hit testing in its MouseArea
// Usage — add content as normal children; they sit above the mask but
// below the border (z=2) automatically, so clipping always looks correct:
//   HexItem {
//       id: hex
//       radius: 100
//       selectedBorderColor: colors.primary
//       accentColor: colors.primary
//       isSelected: someCondition
//       onClicked: doSomething()
//       onHovered: markSelected()

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

//       Item {                           // background fill, clipped to hex
//           anchors.fill: parent
//           Rectangle { anchors.fill: parent; color: "blue" }
//           layer.enabled: true
//           layer.effect: MultiEffect {
//               maskEnabled: true
//               maskSource: hex.mask     // ← reference the built-in mask
//               maskThresholdMin: 0.3
//               maskSpreadAtMin: 0.3
//           }
//       }
//   }
Item {
    // External content children are added at z=0 (default), so they render
    // above the mask (same z, later index) but below border + mouse (z=2, z=3).

    id: root

    // ── Geometry ──────────────────────────────────────────────
    property real radius: 100
    readonly property real cx: radius
    readonly property real cy: height / 2
    // Expose the clip mask for external content layers (maskSource: hex.mask)
    readonly property alias mask: _mask
    // ── State ─────────────────────────────────────────────────
    property bool isSelected: false
    readonly property bool isHovered: _mouse.containsMouse
    // ── Border ────────────────────────────────────────────────
    property color borderColor: Qt.rgba(0, 0, 0, 0.5)
    property color selectedBorderColor: Qt.rgba(0, 0, 0, 0.5)
    property real borderWidth: 1.5
    property real selectedBorderWidth: 3
    // ── Accent rim (bottom-left → bottom-right path) ──────────
    property color accentColor: Qt.rgba(0, 0, 0, 0)
    // transparent = hidden
    property real accentWidth: 3
    // ── Internal geometry constants ───────────────────────────
    readonly property real _cos30: 0.866025
    readonly property real _sin30: 0.5

    // ── Signals ───────────────────────────────────────────────
    signal clicked(var mouse)
    signal rightClicked(var mouse)
    signal hovered()

    width: radius * 2
    height: Math.ceil(radius * 1.73205)

    // ── Hex clip mask (z=0) ───────────────────────────────────
    // Invisible but rendered to an offscreen texture so MultiEffect
    // can read it as a mask from any content layer referencing `mask`.
    Item {
        id: _mask

        anchors.fill: parent
        visible: false
        layer.enabled: true
        z: 0

        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "white"
                strokeColor: "transparent"
                startX: root.cx + root.radius
                startY: root.cy

                PathLine {
                    x: root.cx + root.radius * root._sin30
                    y: root.cy - root.radius * root._cos30
                }

                PathLine {
                    x: root.cx - root.radius * root._sin30
                    y: root.cy - root.radius * root._cos30
                }

                PathLine {
                    x: root.cx - root.radius
                    y: root.cy
                }

                PathLine {
                    x: root.cx - root.radius * root._sin30
                    y: root.cy + root.radius * root._cos30
                }

                PathLine {
                    x: root.cx + root.radius * root._sin30
                    y: root.cy + root.radius * root._cos30
                }

                PathLine {
                    x: root.cx + root.radius
                    y: root.cy
                }

            }

        }

    }

    // ── Border outline (z=2) ──────────────────────────────────
    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        z: 2

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.isSelected ? root.selectedBorderColor : root.borderColor
            strokeWidth: root.isSelected ? root.selectedBorderWidth : root.borderWidth
            startX: root.cx + root.radius
            startY: root.cy

            PathLine {
                x: root.cx + root.radius * root._sin30
                y: root.cy - root.radius * root._cos30
            }

            PathLine {
                x: root.cx - root.radius * root._sin30
                y: root.cy - root.radius * root._cos30
            }

            PathLine {
                x: root.cx - root.radius
                y: root.cy
            }

            PathLine {
                x: root.cx - root.radius * root._sin30
                y: root.cy + root.radius * root._cos30
            }

            PathLine {
                x: root.cx + root.radius * root._sin30
                y: root.cy + root.radius * root._cos30
            }

            PathLine {
                x: root.cx + root.radius
                y: root.cy
            }

            Behavior on strokeColor {
                ColorAnimation {
                    duration: 120
                }

            }

            Behavior on strokeWidth {
                NumberAnimation {
                    duration: 120
                }

            }

        }

    }

    // ── Accent rim (z=2) ──────────────────────────────────────
    // Strokes left → bottom-left → bottom-right — the signature bottom glow.
    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        visible: root.accentColor.a > 0
        z: 2

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.accentColor
            strokeWidth: root.accentWidth
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: root.cx - root.radius
            startY: root.cy

            PathLine {
                x: root.cx - root.radius * root._sin30
                y: root.cy + root.radius * root._cos30
            }

            PathLine {
                x: root.cx + root.radius * root._sin30
                y: root.cy + root.radius * root._cos30
            }

        }

    }

    // ── Hit-accurate mouse area (z=3) ─────────────────────────
    // Overrides `contains` so only the actual hex polygon registers
    // hover/click, not the rectangular bounding box.
    MouseArea {
        id: _mouse

        function contains(point) {
            var dx = Math.abs(point.x - root.cx);
            var dy = Math.abs(point.y - root.cy);
            return dy <= root._cos30 * root.radius && dx <= root.radius - dy * 0.57735;
        }

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 3
        onContainsMouseChanged: {
            if (containsMouse)
                root.hovered();

        }
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked(mouse);
            else
                root.clicked(mouse);
        }
    }

}
