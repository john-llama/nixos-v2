pragma ComponentBehavior: Bound

// Month view used by the clock panel: today's date as the heading, a
// year-progress rail, a Sunday-first grid with ISO week numbers down a gutter,
// and month stepping beneath it. The grid is a read-out rather than a picker:
// today is the only marked day.
import QtQuick
import Quickshell
import "../primitives"
import "../../services"
import "../.."

Item {
    id: root

    readonly property int cellHeight: 34
    readonly property int cellSpacing: 2
    readonly property int weekColumnWidth: 28
    readonly property int gutterWidth: 12
    // Seven day columns share what the week column and gutter leave.
    readonly property int cellWidth: Math.floor((width - weekColumnWidth - gutterWidth
        - cellSpacing * 8) / 7)
    readonly property real gridWidth: weekColumnWidth + gutterWidth + cellWidth * 7
        + cellSpacing * 8

    readonly property color foreground: Theme.textPrimary
    readonly property color labelColor: Qt.darker(foreground, 1.5)
    readonly property color faintColor: Qt.darker(foreground, 1.9)

    property date visibleMonth: new Date()
    readonly property date today: calendarClock.date
    readonly property bool viewingCurrentMonth: visibleMonth.getFullYear() === today.getFullYear()
        && visibleMonth.getMonth() === today.getMonth()

    // Pinned to today, not to the month on screen.
    readonly property real yearDone: {
        const year = today.getFullYear();
        const start = Date.UTC(year, 0, 1);
        const day = Math.round((Date.UTC(year, today.getMonth(), today.getDate()) - start) / 86400000);
        const total = Math.round((Date.UTC(year + 1, 0, 1) - start) / 86400000);
        return Math.max(0, Math.min(1, day / total));
    }

    // Always six rows, so the panel is as tall in February as in August.
    readonly property var weeks: {
        const first = new Date(visibleMonth.getFullYear(), visibleMonth.getMonth(), 1);
        const start = new Date(first);
        start.setDate(1 - first.getDay());
        const rows = [];
        for (let row = 0; row < 6; row++) {
            const days = [];
            for (let column = 0; column < 7; column++) {
                const value = new Date(start);
                value.setDate(start.getDate() + row * 7 + column);
                days.push({
                    day: value.getDate(),
                    inMonth: value.getMonth() === visibleMonth.getMonth(),
                    weekend: column === 0 || column === 6,
                    today: value.getFullYear() === today.getFullYear()
                        && value.getMonth() === today.getMonth()
                        && value.getDate() === today.getDate()
                });
            }
            // A Sunday-first row takes the ISO week of its Monday.
            const monday = new Date(start);
            monday.setDate(start.getDate() + row * 7 + 1);
            rows.push({ week: root.isoWeek(monday), days });
        }
        return rows;
    }

    implicitHeight: calendarColumn.implicitHeight

    function resetToToday(): void {
        visibleMonth = new Date(today.getFullYear(), today.getMonth(), 1);
    }

    function moveMonth(offset: int): void {
        visibleMonth = new Date(visibleMonth.getFullYear(),
            visibleMonth.getMonth() + offset, 1);
    }

    function isoWeek(value: date): int {
        const date = new Date(Date.UTC(value.getFullYear(), value.getMonth(), value.getDate()));
        const weekday = date.getUTCDay() || 7;
        date.setUTCDate(date.getUTCDate() + 4 - weekday);
        const yearStart = Date.UTC(date.getUTCFullYear(), 0, 1);
        return Math.ceil(((date.getTime() - yearStart) / 86400000 + 1) / 7);
    }

    SystemClock {
        id: calendarClock
        precision: SystemClock.Minutes
    }

    Component.onCompleted: resetToToday()

    Column {
        id: calendarColumn
        width: parent.width
        spacing: 16

        // --- today; once the view has stepped away, clicking returns to it ---
        Item {
            width: parent.width
            height: heroRow.height + 6

            Row {
                id: heroRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18

                ShellText {
                    // Baseline-aligned so the glyph sits on the date's line.
                    anchors.baseline: heroDate.baseline
                    text: "󰃭"
                    color: heroMouse.containsMouse ? Theme.textSecondary : root.foreground
                    size: 40
                }

                ShellText {
                    id: heroDate
                    text: Qt.formatDate(root.today, "MMMM d")
                    color: heroMouse.containsMouse ? Theme.textSecondary : root.foreground
                    size: 44
                    font.bold: true
                }
            }

            MouseArea {
                id: heroMouse
                anchors.fill: heroRow
                enabled: !root.viewingCurrentMonth
                hoverEnabled: enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.resetToToday()
            }
        }

        // --- year progress ---
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.gridWidth
            height: 16

            ShellText {
                id: yearLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.today.getFullYear()
                color: root.labelColor
                size: 11
                font.letterSpacing: 1
            }

            ShellText {
                id: yearPercent
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(root.yearDone * 100) + "%"
                size: 11
            }

            Rectangle {
                anchors {
                    left: yearLabel.right
                    right: yearPercent.left
                    leftMargin: 12
                    rightMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                height: 6
                radius: height / 2
                color: Utils.alpha(Theme.base05, 0.12)

                Rectangle {
                    width: Math.round(parent.width * root.yearDone)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.base05
                }
            }
        }

        // --- month grid ---
        Item {
            width: parent.width
            height: gridColumn.y + gridColumn.height

            WheelHandler {
                onWheel: event => {
                    // Side-scrolls report y === 0; they would otherwise all read as "next month".
                    if (event.angleDelta.y !== 0)
                        root.moveMonth(event.angleDelta.y > 0 ? -1 : 1);
                }
            }

            Column {
                id: gridColumn
                y: 8
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3

                Row {
                    id: headerRow
                    spacing: root.cellSpacing

                    ShellText {
                        width: root.weekColumnWidth
                        height: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "W"
                        color: root.faintColor
                        size: 10
                        font.letterSpacing: 1
                        font.bold: true
                    }

                    Item {
                        width: root.gutterWidth
                        height: 16
                    }

                    Repeater {
                        model: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

                        ShellText {
                            required property string modelData
                            width: root.cellWidth
                            height: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData
                            color: root.labelColor
                            size: 10
                            font.letterSpacing: 1
                            font.bold: true
                        }
                    }
                }

                Repeater {
                    model: root.weeks

                    Row {
                        id: weekRow
                        required property var modelData
                        spacing: root.cellSpacing

                        ShellText {
                            width: root.weekColumnWidth
                            height: root.cellHeight
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: weekRow.modelData.week
                            color: root.faintColor
                            size: 10
                        }

                        Item {
                            width: root.gutterWidth
                            height: root.cellHeight
                        }

                        Repeater {
                            model: weekRow.modelData.days

                            Rectangle {
                                required property var modelData

                                width: root.cellWidth
                                height: root.cellHeight
                                radius: PanelService.rounding
                                // Today is outlined, not filled: a lit-up block shouts over a grid this quiet.
                                color: "transparent"
                                border.width: modelData.today ? 1 : 0
                                border.color: Utils.alpha(Theme.base05, 0.6)

                                ShellText {
                                    anchors.centerIn: parent
                                    text: parent.modelData.day
                                    color: !parent.modelData.inMonth ? Qt.darker(root.foreground, 2.2)
                                        : parent.modelData.weekend ? Qt.darker(root.foreground, 1.45)
                                        : root.foreground
                                    size: 13
                                    font.bold: parent.modelData.today
                                }
                            }
                        }
                    }
                }
            }

            // Hairline down the week-number gutter, beside the day rows only.
            Rectangle {
                x: gridColumn.x + root.weekColumnWidth + root.cellSpacing
                    + Math.round((root.gutterWidth - width) / 2)
                y: gridColumn.y + headerRow.height + gridColumn.spacing
                width: 1
                height: gridColumn.height - headerRow.height - gridColumn.spacing
                color: root.foreground
                opacity: 0.1
            }
        }

        // --- month stepping ---
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.gridWidth
            height: 32

            ShellText {
                anchors.centerIn: parent
                text: Qt.formatDate(root.visibleMonth, "MMMM yyyy").toUpperCase()
                color: Qt.darker(root.foreground, 1.4)
                size: 13
                font.letterSpacing: 1
            }

            Repeater {
                model: [
                    { glyph: "󰅁", offset: -1 },
                    { glyph: "󰅂", offset: 1 }
                ]

                Rectangle {
                    required property var modelData

                    anchors.left: modelData.offset < 0 ? parent.left : undefined
                    anchors.right: modelData.offset > 0 ? parent.right : undefined
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 28
                    radius: PanelService.rounding
                    color: monthMouse.pressed ? Utils.alpha(Theme.base05, 0.2)
                        : monthMouse.containsMouse ? Theme.selectionFill : "transparent"

                    ShellText {
                        anchors.centerIn: parent
                        text: parent.modelData.glyph
                        size: 16
                    }

                    MouseArea {
                        id: monthMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.moveMonth(parent.modelData.offset)
                    }
                }
            }
        }
    }
}
