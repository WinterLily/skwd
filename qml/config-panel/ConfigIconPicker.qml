import ".."
import QtQuick
import QtQuick.Controls
import Quickshell.Io

Rectangle {
    id: root

    property var panel
    property var allIcons: []
    property var _filteredModel
    property string _searchText: ""

    function _loadIcons() {
        var text = _iconDataFile.text().trim();
        if (!text)
            return ;

        try {
            allIcons = JSON.parse(text);
            _rebuildFiltered();
        } catch (e) {
            console.log("ConfigIconPicker: Failed to parse mdi-icons.json:", e);
        }
    }

    function focusSearch() {
        iconSearchInput.text = "";
        iconSearchInput.forceActiveFocus();
        _rebuildFiltered();
    }

    function _rebuildFiltered() {
        _filteredModel.clear();
        var q = _searchText.toLowerCase();
        for (var i = 0; i < allIcons.length; i++) {
            var item = allIcons[i];
            if (!q || item.n.indexOf(q) >= 0)
                _filteredModel.append({
                "name": item.n,
                "glyph": item.g
            });

        }
    }

    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.85)
    visible: panel._iconPickerVisible
    z: 100
    onVisibleChanged: {
        if (visible)
            _rebuildFiltered();

    }

    FileView {
        id: _iconDataFile

        path: Config.configDir + "/data/mdi-icons.json"
        preload: true
        watchChanges: true
        onLoaded: root._loadIcons()
        onFileChanged: {
            _iconDataFile.reload();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.panel._iconPickerVisible = false
    }

    Rectangle {
        width: 700
        height: 560
        anchors.centerIn: parent
        radius: 12
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.95)
        border.width: 1
        border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)

        MouseArea {
            anchors.fill: parent
            onClicked: {
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            // Header row: title + search + manual paste
            Row {
                width: parent.width
                spacing: 12

                Text {
                    text: "󰀻 ICON PICKER"
                    font.family: Style.fontFamilyIcons
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                    color: Colors.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: 8
                    height: 1
                }

                Rectangle {
                    width: 260
                    height: 30
                    radius: 6
                    color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.6)
                    border.width: iconSearchInput.activeFocus ? 1 : 0
                    border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)
                    anchors.verticalCenter: parent.verticalCenter

                    TextInput {
                        id: iconSearchInput

                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Style.fontFamily
                        font.pixelSize: 12
                        color: Colors.surfaceText
                        clip: true
                        selectByMouse: true
                        onTextChanged: {
                            root._searchText = text.trim();
                            root._rebuildFiltered();
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "󰍉 search icons by name..."
                            font.family: Style.fontFamilyIcons
                            font.pixelSize: 11
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.25)
                            visible: !parent.text && !parent.activeFocus
                        }

                    }

                }

                Item {
                    width: 4
                    height: 1
                }

                Rectangle {
                    width: 120
                    height: 30
                    radius: 6
                    color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.6)
                    border.width: manualIconInput.activeFocus ? 1 : 0
                    border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)
                    anchors.verticalCenter: parent.verticalCenter

                    TextInput {
                        id: manualIconInput

                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Style.fontFamilyIcons
                        font.pixelSize: 14
                        color: Colors.tertiary
                        clip: true
                        selectByMouse: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "paste glyph"
                            font.family: Style.fontFamily
                            font.pixelSize: 10
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.25)
                            visible: !parent.text && !parent.activeFocus
                        }

                    }

                }

                Rectangle {
                    width: applyManualLabel.implicitWidth + 16
                    height: 30
                    radius: 6
                    color: applyManualMouse.containsMouse ? (Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)) : (Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15))
                    anchors.verticalCenter: parent.verticalCenter
                    visible: manualIconInput.text !== ""

                    Text {
                        id: applyManualLabel

                        anchors.centerIn: parent
                        text: "APPLY"
                        font.family: Style.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Colors.primary
                    }

                    MouseArea {
                        id: applyManualMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var key = root.panel._iconPickerTargetKey;
                            if (key && manualIconInput.text) {
                                if (!root.panel.appsData[key])
                                    root.panel.appsData[key] = {
                                };

                                root.panel.appsData[key].icon = manualIconInput.text;
                                root.panel.hasUnsavedChanges = true;
                                root.panel.appsDataChanged();
                            }
                            root.panel._iconPickerVisible = false;
                            manualIconInput.text = "";
                        }
                    }

                }

            }

            Text {
                text: root._filteredModel.count + " icons" + (root._searchText ? " matching \"" + root._searchText + "\"" : "")
                font.family: Style.fontFamily
                font.pixelSize: 10
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
            }

            // Icon grid
            GridView {
                id: iconGrid

                width: parent.width
                height: parent.height - 72
                cellWidth: 52
                cellHeight: 52
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root._filteredModel

                delegate: Rectangle {
                    width: 48
                    height: 48
                    radius: 8
                    color: iconCellMouse.containsMouse ? (Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25)) : (Qt.rgba(Colors.surfaceVariant.r, Colors.surfaceVariant.g, Colors.surfaceVariant.b, 0.2))
                    border.width: iconCellMouse.containsMouse ? 1 : 0
                    border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4)

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -6
                        text: model.glyph
                        font.family: Style.fontFamilyIcons
                        font.pixelSize: 22
                        color: iconCellMouse.containsMouse ? (Colors.primary) : (Colors.surfaceText)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        text: {
                            var n = model.name;
                            var parts = n.split(" ");
                            return parts[0].length > 8 ? parts[0].substring(0, 7) + "…" : parts[0];
                        }
                        font.family: Style.fontFamily
                        font.pixelSize: 7
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                    }

                    MouseArea {
                        id: iconCellMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var key = root.panel._iconPickerTargetKey;
                            if (key) {
                                if (!root.panel.appsData[key])
                                    root.panel.appsData[key] = {
                                };

                                root.panel.appsData[key].icon = model.glyph;
                                root.panel.hasUnsavedChanges = true;
                                root.panel.appsDataChanged();
                            }
                            root.panel._iconPickerVisible = false;
                        }

                        ToolTip {
                            id: iconTooltip

                            visible: iconCellMouse.containsMouse
                            text: model.name
                            delay: 400
                        }

                    }

                }

            }

        }

    }

    _filteredModel: ListModel {
    }

}
