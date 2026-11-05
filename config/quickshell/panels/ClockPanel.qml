pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../components/panels"
import "../components/primitives"
import "../services"
import ".."

// Month calendar opened from the bar clock.
Drawer {
    id: root

    barItems: ["clock"]
    fallbackAlignment: "center"
    // Wide side margins keep the calendar airy; the width grows to match so
    // the grid and heading keep their room.
    contentHorizontalMargins: 40
    contentTopMargin: 32
    contentBottomMargin: 28
    panelWidth: 500

    onOpenChanged: {
        if (!open)
            return;
        monthCalendar.resetToToday();
    }

    MonthCalendar {
        id: monthCalendar
        width: parent.width
    }
}
