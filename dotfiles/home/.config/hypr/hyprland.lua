-- Hyprland config for Noctalia, from the NUC's config, adapted for tinyputy (laptop).
-- Shell: Noctalia (bar, launcher, notifications, lock, clipboard). Terminal: kitty.
-- Previous laptop config: hyprland.lua.bak-before-nuc

-- ── Monitor ──────────────────────────────────────────────────────────────────
hl.monitor({ output = "HDMI-A-2", mode = "3840x2160@240", position = "auto", scale = 1.25 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 }) -- anything else

-- ── Programs ─────────────────────────────────────────────────────────────────
local terminal = "kitty"          -- NUC: foot (not installed here)
local browser  = "zen-browser"
local files    = "kitty --class yazi --title Yazi -e yazi"

-- ── Environment ──────────────────────────────────────────────────────────────
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
-- Qt/KDE apps (Dolphin) read ~/.config/kdeglobals, which noctalia's kcolorscheme template writes.
hl.env("QT_QPA_PLATFORMTHEME", "kde")  -- PC: qt6ct not installed; laptop uses qt6ct
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- ── Autostart ────────────────────────────────────────────────────────────────
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    -- NUC also starts gnome-keyring-daemon; not installed on this laptop.
    -- Password prompts for admin actions (pkexec, e.g. noctalia msg greeter-sync)
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("noctalia")
    -- Runs in the tray so the Firefox extension can unlock with fingerprint
    hl.exec_cmd("bitwarden-desktop --start-minimized")
end)

-- ── Look and input ───────────────────────────────────────────────────────────
hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 1,
        resize_on_border = true,
        layout = "dwindle",
    },
    decoration = {
        rounding = 12,
        rounding_power = 2,
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },
        -- Noctalia's panels + kitty's background_opacity; Hyprland draws the frost.
        blur = {
            enabled = true,
            xray = true,        -- blur only the wallpaper, not windows behind
            variant = 1,        -- frost (0 kawase, 1 frost, 8 acrylic, 10 haze; see theme/hypr/blur-try.sh)
            size = 3,           -- blur radius; small keeps it light frosted glass, not fog
            passes = 3,
            noise = 0.05,       -- grain so the frost reads as a material
            contrast = 0.9,
            brightness = 0.85,
            vibrancy = 0.2,
            glass = {
                size = 24,          -- frost texture pattern size, px
                roughness = 0.8,    -- relief shading strength (max 1.0)
                refraction = 6,     -- how far it bends what's behind, px (max 20)
            },
        },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    misc = {
        force_default_wallpaper = 0,   -- Noctalia draws the wallpaper
        disable_hyprland_logo   = true,
    },
    input = {
        kb_layout = "us",
        numlock_by_default = true,
        repeat_delay = 250,
        repeat_rate = 35,
        follow_mouse = 1,
        touchpad = { natural_scroll = true },
    },
})

-- Laptop: three-finger swipe between workspaces
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Blur behind Noctalia's surfaces (from theme/hypr/noctalia-blur.lua).
hl.layer_rule({
    name = "noctalia",
    match = {
        namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
    },
    no_anim = true,
    ignore_alpha = 0.5,
    blur = true,
    blur_popups = true,
})

-- Noctalia Settings is a normal window that Noctalia always draws opaque.
-- Hyprland fades the whole window (text too) and blurs what's behind it.
hl.window_rule({
    name = "noctalia-settings-glass",
    match = { class = "^dev\\.noctalia\\.Noctalia$" },
    float = true,
    size  = "monitor_w*0.5625 monitor_h*0.85",
    opacity = "0.90 0.82",   -- focused, unfocused
})

-- Ignore maximize requests from apps; fix XWayland drag glitches.
hl.window_rule({ name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- ── Keybinds ─────────────────────────────────────────────────────────────────
local n = "noctalia msg "

-- 1. Shell
hl.bind("SUPER + A", hl.dsp.exec_cmd(n .. "panel-open launcher"), { description = "Launcher" })
hl.bind("SUPER + Space", hl.dsp.exec_cmd(n .. "panel-toggle launcher"), { description = "Launcher" })
hl.bind("SUPER + N", hl.dsp.exec_cmd(n .. "panel-open control-center"), { description = "Control center" })
hl.bind("SUPER + P", hl.dsp.exec_cmd(n .. "panel-open session"), { description = "Session menu" })
hl.bind("SUPER + L", hl.dsp.exec_cmd(n .. "session lock"), { description = "Lock" })
hl.bind("SUPER + comma", hl.dsp.exec_cmd(n .. "settings-toggle"), { description = "Noctalia settings" })
-- SUPER + / : searchable keybind panel (noctalia plugin kenn/keybind-cheatsheet, if installed).
hl.bind("SUPER + slash", hl.dsp.exec_cmd(n .. "panel-toggle kenn/keybind-cheatsheet:cheatsheet"),
    { description = "Show shortcuts" })
hl.bind("SUPER + Escape", hl.dsp.exec_cmd(n .. "panel-close"), { description = "Close panel" })
hl.bind("ALT + Tab", hl.dsp.exec_cmd(n .. "window-switcher hold"), { description = "Window switcher" })
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd(n .. "window-switcher hold reverse"), { description = "Window switcher (reverse)" })
-- Escape hatch if the shell is broken: end the session.
hl.bind("SUPER + SHIFT + ALT + E", hl.dsp.exec_cmd("loginctl terminate-session $XDG_SESSION_ID"),
    { description = "Log out" })

-- 2. Apps
hl.bind("SUPER + T", hl.dsp.exec_cmd(terminal), { description = "Terminal" })
hl.bind("SUPER + Return", hl.dsp.exec_cmd(terminal), { description = "Terminal" })
hl.bind("SUPER + B", hl.dsp.exec_cmd(browser), { description = "Browser" })
hl.bind("SUPER + E", hl.dsp.exec_cmd(files), { description = "Files" })

-- 3. Windows
hl.bind("SUPER + C", hl.dsp.window.close(), { description = "Close" })
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Close" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
    { description = "Fullscreen" })
hl.bind("SUPER + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),
    { description = "Maximize" })
hl.bind("SUPER + ALT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Float/Tile" })
hl.bind("SUPER + ALT + P", hl.dsp.window.pin(), { description = "Pin" })
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"), { description = "Toggle split" })
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Drag window" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

local arrows = { Left = "l", Right = "r", Up = "u", Down = "d" }
for key, dir in pairs(arrows) do
    hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = dir }), { description = "Focus " .. key:lower() })
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }), { description = "Move window " .. key:lower() })
end

-- 4. Workspaces (key 0 = 10)
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = i }), { description = "Go to workspace " .. i })
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), { description = "Move window to workspace " .. i })
end
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace" })
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace" })

-- 5. Media (laptop: through Noctalia so its on-screen popup shows)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(n .. "volume-up"),
    { locked = true, repeating = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(n .. "volume-down"),
    { locked = true, repeating = true, description = "Volume down" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(n .. "volume-mute"), { locked = true, description = "Mute" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, description = "Mic mute" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(n .. "brightness-up"),
    { locked = true, repeating = true, description = "Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(n .. "brightness-down"),
    { locked = true, repeating = true, description = "Brightness down" })
-- Requires playerctl (sudo pacman -S playerctl)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play / pause" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play / pause" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Next track" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Previous track" })

-- 6. Screenshot
hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"), { locked = true, description = "Full screen to clipboard" })
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd(n .. "screenshot-region"), { description = "Region screenshot" })



-- For Noctalia Color templates
require("noctalia").apply_theme()
