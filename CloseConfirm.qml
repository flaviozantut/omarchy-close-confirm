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
  property string targetPid: ""
  property string targetStarted: ""

  readonly property var addressPattern: /^0x[0-9A-Fa-f]+$/

  function open(payloadJson) {
    if (root.opened) return
    var data = {}
    try { data = JSON.parse(payloadJson || "{}") } catch (e) { return }
    if (!data || typeof data !== "object") return
    var address = data.address
    var pid = String(data.pid || "")
    var started = data.started
    if (typeof data.pid !== "number"
        || typeof address !== "string" || !root.addressPattern.test(address)
        || !/^[1-9][0-9]*$/.test(pid)
        || typeof started !== "string" || !/^[0-9]+$/.test(started)) return
    root.targetAddress = address
    root.targetTitle = typeof data.title === "string" ? data.title : ""
    root.targetPid = pid
    root.targetStarted = started
    root.opened = true
    confirmDialog.selectedIndex = 1
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
    root.targetAddress = ""
    root.targetTitle = ""
    root.targetPid = ""
    root.targetStarted = ""
  }

  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "flaviozantut.close-confirm")
  }

  function toggle() {
    if (root.opened) root.dismiss()
  }

  function doClose() {
    if (!root.opened || !root.targetAddress || !root.targetPid || !root.targetStarted) return
    var command = [Quickshell.env("HOME") + "/.config/omarchy/plugins/flaviozantut.close-confirm/bin/omarchy-close-confirm",
                   "--close", root.targetAddress, root.targetPid, root.targetStarted]
    // Invalidate before launching: a second confirmation cannot reuse this request.
    root.dismiss()
    Quickshell.execDetached(command)
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
