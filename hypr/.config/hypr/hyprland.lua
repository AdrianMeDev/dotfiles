-- Hyprland configuration (Lua API).
-- Requires Hyprland >= 0.57: the compositor no longer loads hyprland.conf and
-- reads only this file. Wiki: https://wiki.hypr.land/Configuring/Basics/Using-Lua/
-- Theme values come from theme/tokens.toml and are checked by tests/test_theme.py.

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.config({
  input = {
    kb_layout = "us",
    follow_mouse = 1,
    touchpad = { natural_scroll = true },
  },
  general = {
    gaps_in = 4,
    gaps_out = 8,
    border_size = 2,
    col = {
      active_border = 0xff7aa2f7,
      inactive_border = 0xff414868,
    },
  },
  decoration = {
    rounding = 8,
    active_opacity = 0.75,
    inactive_opacity = 0.75,
    blur = {
      enabled = true,
      size = 8,
      passes = 3,
    },
  },
})

-- Autostart
hl.on("hyprland.start", function()
  hl.dsp.exec_cmd("waybar")
  hl.dsp.exec_cmd("mako")
  hl.dsp.exec_cmd("hypridle")
  hl.dsp.exec_cmd("hyprpaper")
  hl.dsp.exec_cmd("wl-paste --watch cliphist store")
end)

-- Window rules
hl.window_rule({ name = "float-pavucontrol", match = { class = "^(org.pulseaudio.pavucontrol)$" }, float = true })
hl.window_rule({ name = "float-polkit", match = { class = "^(org.kde.polkit-kde-authentication-agent-1)$" }, float = true })

-- Key bindings live in bindings.lua (same directory).
require("bindings")
