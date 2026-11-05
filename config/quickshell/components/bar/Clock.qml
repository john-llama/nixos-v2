// Compact bar clock with a panel for the time and calendar.
import QtQuick
import Quickshell
import "../primitives"
import "../../panels"
import "../../services"

Item {
    id: root

    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true

    implicitWidth: label.implicitWidth + PanelService.barItemPadding * 2
    implicitHeight: PanelService.barItemHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        visible: opacity > 0
        anchors.bottom: parent.bottom
        anchors.left: label.left
        anchors.right: label.right
        height: 2
        radius: PanelService.rounding
        opacity: root.opened || mouseArea.containsMouse ? 1 : 0
        color: Theme.base05

        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    ShellText {
        id: label

        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: Qt.formatDateTime(clock.date, "dddd HH:mm")
        font.pixelSize: 13
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PanelService.toggle(root)
    }

    ClockPanel {
        anchorItem: root
    }
}
