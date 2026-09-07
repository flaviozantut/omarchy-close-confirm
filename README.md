# Omarchy Close Confirm

An [Omarchy](https://omarchy.org/) shell plugin that asks for confirmation
before closing the focused window, instead of closing it instantly.

![kind](https://img.shields.io/badge/kind-overlay-blue)

## Why

By default, closing a window in Omarchy is instant — one accidental keypress
and an unsaved document, terminal session, or form is gone. This plugin adds
a confirmation dialog (Close/Cancel) before the window is actually closed.

![Close confirmation dialog](screenshots/confirm-dialog.png)

*Mockup styled after the shell's default theme tokens (`menu.*` colors),
built for this README — not a live screen capture.*

## What's included

- `manifest.json` + `CloseConfirm.qml` — the shell overlay plugin itself
  (id: `flaviozantut.close-confirm`).
- `bin/omarchy-close-confirm` — a helper script that captures the focused
  window and asks the overlay to confirm before closing it.

The overlay only reacts when asked to `open`/`toggle` — it does not bind any
key on its own. Wiring a keybinding to the helper script is a manual step,
described below.

## Install

1. Clone the plugin into your user plugins directory:

   ```bash
   git clone https://github.com/flaviozantut/omarchy-close-confirm.git \
     ~/.config/omarchy/plugins/flaviozantut.close-confirm
   ```

   (Or copy just `manifest.json` and `CloseConfirm.qml` there if you prefer
   to keep the helper script elsewhere.)

2. Install the helper script:

   ```bash
   ln -s ~/.config/omarchy/plugins/flaviozantut.close-confirm/bin/omarchy-close-confirm \
     ~/.local/bin/omarchy-close-confirm
   ```

3. Bind it in `~/.config/hypr/bindings.lua`. Unbind the defaults first, or
   Hyprland will run both the old close action and this script on the same
   key:

   ```lua
   hl.unbind("SUPER + Q")
   hl.unbind("SUPER + W")
   o.bind("SUPER + Q", "Close window (confirm)", os.getenv("HOME") .. "/.local/bin/omarchy-close-confirm")
   o.bind("SUPER + W", "Close window (confirm)", os.getenv("HOME") .. "/.local/bin/omarchy-close-confirm")
   ```

4. Force a plugin rescan if it doesn't pick up automatically:

   ```bash
   omarchy-shell shell rescanPlugins
   ```

## Requirements

- Omarchy 4.0.2+ (uses the `hl.dsp`/`hl.dispatch` Lua Hyprland API and the
  stock `ConfirmDialog` shell component).
- `jq` (used by the helper script to parse `hyprctl activewindow -j`).

## License

MIT — see [LICENSE](LICENSE).
