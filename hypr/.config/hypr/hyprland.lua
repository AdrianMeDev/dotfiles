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

-- Workspaces 1-5 on the first monitor, 6-9 on the second (same split as GlazeWM's
-- bind_to_monitor). "0"/"1" are Hyprland monitor IDs (connection order; `hyprctl monitors`).
-- persistent: Waybar lists exactly these per monitor (no per-output persistent-workspaces there).
-- With a single monitor the rule cannot resolve and all workspaces stay on it.
for ws = 1, 9 do
  hl.workspace_rule({ workspace = tostring(ws), monitor = ws <= 5 and "0" or "1", persistent = true })
end

hl.config({
  -- Bibata ships Xcursor images. no_warps = false: the cursor follows keyboard focus to the other monitor.
  cursor = { enable_hyprcursor = false, no_warps = false },
  input = {
    kb_layout = "eu",
    follow_mouse = 1,
    touchpad = { natural_scroll = false },
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
hl.device({ name = "at-translated-set-2-keyboard", kb_layout = "eu", kb_options = "caps:swapescape" })

-- Autostart. hl.exec_cmd runs immediately; hl.dsp.exec_cmd only builds a
-- dispatcher for hl.bind and would do nothing here.
hl.on("hyprland.start", function()
  -- Without uwsm nothing activates graphical-session.target, which xdg-desktop-portal needs.
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE")
  hl.exec_cmd("systemctl --user start hyprland-session.target")
  hl.exec_cmd("waybar")
  hl.exec_cmd("mako")
  hl.exec_cmd("hypridle")
  -- Secret Service (org.freedesktop.secrets) for Brave, Zed and gh; asks for a keyring password on first use.
  hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
  -- polkit-kde lives in /usr/libexec/kf6 on Fedora and in /usr/lib on Arch.
  hl.exec_cmd("sh -c 'for a in /usr/libexec/kf6/polkit-kde-authentication-agent-1 /usr/lib/polkit-kde-authentication-agent-1; do [ -x \"$a\" ] && exec \"$a\"; done'")
  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("wl-paste --watch cliphist store")
end)

-- Window rules
hl.window_rule({ name = "float-pavucontrol", match = { class = "^(org.pulseaudio.pavucontrol)$" }, float = true })
hl.window_rule({ name = "float-blueman", match = { class = "^(\\.?blueman-manager(-wrapped)?)$" }, float = true })
hl.window_rule({ name = "float-nmtui", match = { class = "^(nmtui)$" }, float = true })
hl.window_rule({ name = "float-polkit", match = { class = "^(org.kde.polkit-kde-authentication-agent-1)$" }, float = true })

-- Key bindings live in bindings.lua (same directory).
require("bindings")
-- Volume, brightness and playback keys live in media.lua.
require("media")
