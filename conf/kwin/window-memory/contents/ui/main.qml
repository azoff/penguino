// Loads the real script with a timestamp so a reload picks up edits: KWin's
// QML engine otherwise keeps serving the compiled copy of an unchanged URL.
import QtQuick
Loader { source: Qt.resolvedUrl("WindowMemory.qml") + "?t=" + Date.now() }
