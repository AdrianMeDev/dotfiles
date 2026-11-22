-- Hyprland configuration (Lua API).
-- Requires Hyprland >= 0.57: the compositor no longer loads hyprland.conf and
-- reads only this file. Wiki: https://wiki.hypr.land/Configuring/Basics/Using-Lua/
-- Theme values come from theme/tokens.toml and are checked by tests/test_theme.py.

-- qt6ct also accepts the qt5ct platform theme name.
-- Display managers start Hyprland with a minimal PATH; user-local tools
-- (e.g. the WezTerm AppImage wrapper from scripts/apps.sh) live in ~/.local/bin.
hl.env("PATH", os.getenv("HOME") .. "/.local/bin:" .. (os.getenv("PATH") or "/usr/local/bin:/usr/bin"))

hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.config({
  -- Bibata ships Xcursor images.
  cursor = { enable_hyprcursor = false },
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

-- Swap Caps Lock and Escape on the built-in laptop keyboard only. The Corne
-- already sends Escape from its own key, a global swap would turn it into Caps Lock.
hl.device({ name = "at-translated-set-2-keyboard", kb_layout = "us", kb_options = "caps:swapescape" })

-- Autostart. hl.exec_cmd runs immediately; hl.dsp.exec_cmd only builds a
-- dispatcher for hl.bind and would do nothing here.
hl.on("hyprland.start", function()
  hl.exec_cmd("waybar")
  hl.exec_cmd("mako")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("wl-paste --watch cliphist store")
end)

-- Window rules
hl.window_rule({ name = "float-pavucontrol", match = { class = "^(org.pulseaudio.pavucontrol)$" }, float = true })
hl.window_rule({ name = "float-polkit", match = { class = "^(org.kde.polkit-kde-authentication-agent-1)$" }, float = true })

-- Key bindings live in bindings.lua (same directory).
require("bindings")
