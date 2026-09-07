import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property string targetAddress: ""
  property string targetTitle: ""

  function open(payloadJson) {
    var data = {}
    try { data = JSON.parse(payloadJson || "{}") } catch (e) {}
    root.targetAddress = data.address || ""
    root.targetTitle = data.title || ""
    root.opened = true
    confirmDialog.selectedIndex = 1
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "flaviozantut.close-confirm")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function doClose() {
    // This Hyprland build routes hyprctl dispatch through its Lua config
    // API instead of the classic "DISPATCHER PARAMS" string form.
    if (root.targetAddress)
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.close(\"address:" + root.targetAddress + "\")"])
    root.dismiss()
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-close-confirm"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (confirmDialog.handleKey(event)) event.accepted = true
      }

      ConfirmDialog {
        id: confirmDialog
        anchors.fill: parent
        opened: root.opened
        message: root.targetTitle ? ("Close “" + root.targetTitle + "”?") : "Close this window?"
        cancelText: "Cancel"
        confirmText: "Close"
        background: Color.menu.background
        foreground: Color.menu.text
        scrim: Color.menu.scrim
        selectedBackground: Color.menu.selectedBackground
        selectedText: Color.menu.selectedText
        fontFamily: Style.font.menuFamily
        cornerRadius: Style.cornerRadius
        onCanceled: root.dismiss()
        onConfirmed: root.doClose()
      }
    }
  }
}
