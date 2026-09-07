-- Ask for confirmation before closing the focused window instead of
-- closing it instantly.
--
-- Load it from ~/.config/hypr/bindings.lua:
--
--   dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/flaviozantut.close-confirm/close-confirm.lua")
--
-- Omarchy binds SUPER+Q and SUPER+W to an instant close by default, so both
-- are cleared before rebinding them to the confirmation script.

local script = os.getenv("HOME") .. "/.config/omarchy/plugins/flaviozantut.close-confirm/bin/omarchy-close-confirm"

hl.unbind("SUPER + Q")
hl.unbind("SUPER + W")
o.bind("SUPER + Q", "Close window (confirm)", script)
o.bind("SUPER + W", "Close window (confirm)", script)
