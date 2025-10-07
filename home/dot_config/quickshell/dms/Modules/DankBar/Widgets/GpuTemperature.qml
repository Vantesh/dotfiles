import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property bool showPercentage: true
    property bool showIcon: true
    property var toggleProcessList
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property var widgetData: null
    property real barThickness: 48
    property real widgetThickness: 30
    property int selectedGpuIndex: (widgetData && widgetData.selectedGpuIndex !== undefined) ? widgetData.selectedGpuIndex : 0
    property bool minimumWidth: (widgetData && widgetData.minimumWidth !== undefined) ? widgetData.minimumWidth : true
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))
    property real displayTemp: {
        if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
            return 0;
        }

        if (selectedGpuIndex >= 0 && selectedGpuIndex < DgopService.availableGpus.length) {
            return DgopService.availableGpus[selectedGpuIndex].temperature || 0;
        }

        return 0;
    }

    function updateWidgetPciId(pciId) {
        // Find and update this widget's pciId in the settings
        const sections = ["left", "center", "right"];
        for (let s = 0; s < sections.length; s++) {
            const sectionId = sections[s];
            let widgets = [];
            if (sectionId === "left") {
                widgets = SettingsData.dankBarLeftWidgets.slice();
            } else if (sectionId === "center") {
                widgets = SettingsData.dankBarCenterWidgets.slice();
            } else if (sectionId === "right") {
                widgets = SettingsData.dankBarRightWidgets.slice();
            }
            for (let i = 0; i < widgets.length; i++) {
                const widget = widgets[i];
                if (typeof widget === "object" && widget.id === "gpuTemp" && (!widget.pciId || widget.pciId === "")) {
                    widgets[i] = {
                        "id": widget.id,
                        "enabled": widget.enabled !== undefined ? widget.enabled : true,
                        "selectedGpuIndex": 0,
                        "pciId": pciId
                    };
                    if (sectionId === "left") {
                        SettingsData.setDankBarLeftWidgets(widgets);
                    } else if (sectionId === "center") {
                        SettingsData.setDankBarCenterWidgets(widgets);
                    } else if (sectionId === "right") {
                        SettingsData.setDankBarRightWidgets(widgets);
                    }
                    return ;
                }
            }
        }
    }

    width: isVertical ? widgetThickness : (gpuTempContent.implicitWidth + horizontalPadding * 2)
    height: isVertical ? (gpuTempColumn.implicitHeight + horizontalPadding * 2) : widgetThickness
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = gpuArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    Component.onCompleted: {
        DgopService.addRef(["gpu"]);
        if (widgetData && widgetData.pciId) {
            DgopService.addGpuPciId(widgetData.pciId);
        } else {
            autoSaveTimer.running = true;
        }
    }
    Component.onDestruction: {
        DgopService.removeRef(["gpu"]);
        if (widgetData && widgetData.pciId) {
            DgopService.removeGpuPciId(widgetData.pciId);
        }

    }

    Connections {
        function onWidgetDataChanged() {
            // Force property re-evaluation by triggering change detection
            root.selectedGpuIndex = Qt.binding(() => {
                return (root.widgetData && root.widgetData.selectedGpuIndex !== undefined) ? root.widgetData.selectedGpuIndex : 0;
            });
        }

        target: SettingsData
    }

    MouseArea {
        id: gpuArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                const globalPos = mapToGlobal(0, 0)
                const currentScreen = parentScreen || Screen
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, width)
                popupTarget.setTriggerPosition(pos.x, pos.y, pos.width, section, currentScreen)
            }
            DgopService.setSortBy("cpu");
            if (root.toggleProcessList) {
                root.toggleProcessList();
            }

        }
    }

    Column {
        id: gpuTempColumn
        visible: root.isVertical
        anchors.centerIn: parent
        spacing: 1

        DankIcon {
            name: "auto_awesome_mosaic"
            size: Theme.barIconSize(barThickness)
            color: {
                if (root.displayTemp > 80) {
                    return Theme.tempDanger;
                }

                if (root.displayTemp > 65) {
                    return Theme.tempWarning;
                }

                return Theme.surfaceText;
            }
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: {
                if (root.displayTemp === undefined || root.displayTemp === null || root.displayTemp === 0) {
                    return "--";
                }

                return Math.round(root.displayTemp).toString();
            }
            font.pixelSize: Theme.barTextSize(barThickness)
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Row {
        id: gpuTempContent
        visible: !root.isVertical
        anchors.centerIn: parent
        spacing: 3

        DankIcon {
            name: "auto_awesome_mosaic"
            size: Theme.barIconSize(barThickness)
            color: {
                if (root.displayTemp > 80) {
                    return Theme.tempDanger;
                }

                if (root.displayTemp > 65) {
                    return Theme.tempWarning;
                }

                return Theme.surfaceText;
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: {
                if (root.displayTemp === undefined || root.displayTemp === null || root.displayTemp === 0) {
                    return "--°";
                }

                return Math.round(root.displayTemp) + "°";
            }
            font.pixelSize: Theme.barTextSize(barThickness)
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideNone

            StyledTextMetrics {
                id: gpuTempBaseline
                font.pixelSize: Theme.barTextSize(barThickness)
                font.weight: Font.Medium
                text: "100°"
            }

            width: root.minimumWidth ? Math.max(gpuTempBaseline.width, paintedWidth) : paintedWidth

            Behavior on width {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }

    }

    Timer {
        id: autoSaveTimer

        interval: 100
        running: false
        onTriggered: {
            if (DgopService.availableGpus && DgopService.availableGpus.length > 0) {
                const firstGpu = DgopService.availableGpus[0];
                if (firstGpu && firstGpu.pciId) {
                    // Save the first GPU's PCI ID to this widget's settings
                    updateWidgetPciId(firstGpu.pciId);
                    DgopService.addGpuPciId(firstGpu.pciId);
                }
            }
        }
    }


}
