import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
  id: root

  function registerBindings() {
    console.log("[Close Confirm] Registering Hyprland bindings from plugin")
    bindProc.running = true
  }

  function unregisterBindings() {
    console.log("[Close Confirm] Restoring default bindings on plugin unload")
    Quickshell.execDetached([
      "hyprctl", "eval",
      'hl.unbind("SUPER + Q"); hl.unbind("SUPER + W"); o.bind("SUPER + Q", "Close window", hl.dsp.window.close()); o.bind("SUPER + W", "Close window", hl.dsp.window.close())'
    ])
  }

  Process {
    id: bindProc
    command: [
      "hyprctl", "eval",
      'local close_confirm_bind_file = (os.getenv("HOME") or "") .. "/.config/omarchy/plugins/flaviozantut.close-confirm/close-confirm.lua"; local close_confirm_handle = io.open(close_confirm_bind_file, "r"); if close_confirm_handle then close_confirm_handle:close(); dofile(close_confirm_bind_file) end'
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim() && text.trim() !== "ok")
          console.log("[Close Confirm] bind out:", text.trim())
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim())
          console.warn("[Close Confirm] bind err:", text.trim())
      }
    }
  }

  Component.onCompleted: {
    registerBindings()
  }

  Component.onDestruction: {
    unregisterBindings()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && event.name === "configreloaded") {
        registerBindings()
      }
    }
  }
}
