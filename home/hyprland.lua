-- Hyprland 0.55+ Lua configuration.
local mainMod = "SUPER"
local terminal = "kitty"
local fileManager = "dolphin"

-- Noctalia generates this module when its Hyprland template is enabled. Keep
-- startup working before the first render or when the template is disabled.
pcall(function()
  require("noctalia").apply_theme()
end)

hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 2,
})

-- nwg-displays writes these files after the first successful Apply. Keep the
-- fallback monitor above so Hyprland can still start before they exist.
pcall(require, "monitors")
pcall(require, "workspaces")

hl.config({
  input = {
    kb_layout = "us",
    follow_mouse = 1,
    sensitivity = 0,
    accel_profile = "flat",
    touchpad = {
      disable_while_typing = true,
      natural_scroll = true,
      scroll_factor = 0.5,
      tap_to_click = true,
      tap_button_map = "lrm",
      clickfinger_behavior = true,
      tap_and_drag = true,
      drag_lock = 1,
      -- Reserve three-finger swipes for Hyprland gestures below.
      drag_3fg = 0,
      middle_button_emulation = false,
    },
  },
  gestures = {
    -- Responsive, macOS-like one-workspace-at-a-time swipes.
    workspace_swipe_distance = 250,
    workspace_swipe_invert = true,
    workspace_swipe_min_speed_to_force = 25,
    workspace_swipe_cancel_ratio = 0.35,
    workspace_swipe_create_new = false,
    workspace_swipe_direction_lock = true,
    workspace_swipe_direction_lock_threshold = 12,
    workspace_swipe_forever = false,
  },
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 2,
    layout = "dwindle",
  },
  decoration = {
    rounding = 10,
    blur = {
      enabled = true,
      size = 10,
      passes = 4,
      -- Keep blur strength consistent while window opacity changes.
      ignore_opacity = true,
    },
  },
  animations = {
    enabled = true,
  },
  dwindle = {
    preserve_split = true,
  },
})

local trackpadDevices = {
  "apple-inc.-magic-trackpad",
  "apple-inc.-magic-trackpad-1",
}

-- Keep external mice on the global flat profile, while trackpads use the
-- adaptive profile that is better suited to precise finger movement.
for _, device in ipairs(trackpadDevices) do
  hl.device({
    name = device,
    sensitivity = 0,
    accel_profile = "adaptive",
  })
end

-- macOS-inspired navigation with Hyprland-native window manipulation.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Four fingers manipulate the active window directly. While dragging, the
-- existing Super+Shift+number binds can carry it to another workspace.
hl.gesture({ fingers = 4, direction = "swipe", action = "move" })
hl.gesture({
  fingers = 4,
  direction = "pinchin",
  action = function()
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset" }))
  end,
})
hl.gesture({
  fingers = 4,
  direction = "pinchout",
  action = function()
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
  end,
})

-- Catppuccin glass treatment for Kitty and Dolphin. The first value is used
-- while focused, the second while unfocused, and fullscreen stays opaque.
hl.window_rule({
  name = "catppuccin-glass-apps",
  match = { class = "^(kitty|dropdown-terminal|org[.]kde[.]dolphin)$" },
  opacity = "0.90 override 0.78 override 1.0 override",
})

hl.on("hyprland.start", function()
  hl.exec_cmd("fcitx5 -d --replace")
  hl.exec_cmd(
    "kitty --class dropdown-terminal --title dropdown-terminal",
    {
      workspace = "special:terminal silent",
      float = true,
      size = { "monitor_w*0.8", "monitor_h*0.5" },
      center = true,
    }
  )
end)

-- 窗口与会话操作。
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind(mainMod .. " + ALT + F4", hl.dsp.window.kill())
hl.bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind("SHIFT + F11", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + D", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + W", function()
  hl.dispatch(hl.dsp.window.float({ action = "set" }))
  hl.dispatch(hl.dsp.window.pin({ action = "toggle" }))
end)
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + CTRL + H", hl.dsp.group.prev())
hl.bind(mainMod .. " + CTRL + L", hl.dsp.group.next())
hl.bind("ALT + Tab", hl.dsp.exec_cmd("noctalia msg window-switcher"))

local directions = {
  left = "l",
  right = "r",
  up = "u",
  down = "d",
}

for key, direction in pairs(directions) do
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = direction }))
  hl.bind(
    mainMod .. " + CTRL + SHIFT + " .. key,
    hl.dsp.window.move({ direction = direction })
  )
end

local resizeSteps = {
  right = { 50, 0 },
  left = { -50, 0 },
  up = { 0, -50 },
  down = { 0, 50 },
}

for key, step in pairs(resizeSteps) do
  hl.bind(
    mainMod .. " + SHIFT + " .. key,
    hl.dsp.window.resize({ x = step[1], y = step[2], relative = true }),
    { repeating = true }
  )
end

-- 常用应用。
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + ALT + T", hl.dsp.workspace.toggle_special("terminal"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("firefox"))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("missioncenter"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd("hypr-command-palette"))

-- 工作区 1–10；数字键 0 对应工作区 10。
for workspace = 1, 10 do
  local key = workspace % 10
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
  hl.bind(
    mainMod .. " + SHIFT + " .. key,
    hl.dsp.window.move({ workspace = workspace, follow = true })
  )
end

hl.bind(mainMod .. " + CTRL + Down", hl.dsp.focus({ workspace = "empty" }))
local externalPointersOnly = {
  device = { inclusive = false, list = trackpadDevices },
}
hl.bind(
  mainMod .. " + mouse_down",
  hl.dsp.focus({ workspace = "e+1" }),
  externalPointersOnly
)
hl.bind(
  mainMod .. " + mouse_up",
  hl.dsp.focus({ workspace = "e-1" }),
  externalPointersOnly
)

hl.bind(mainMod .. " + CTRL + Right", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mainMod .. " + CTRL + Left", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(
  mainMod .. " + ALT + CTRL + Right",
  hl.dsp.window.move({ workspace = "r+1", follow = true })
)
hl.bind(
  mainMod .. " + ALT + CTRL + Left",
  hl.dsp.window.move({ workspace = "r-1", follow = true })
)

local function bindSpecialWorkspace(key, name)
  hl.bind(
    mainMod .. " + SHIFT + " .. key,
    hl.dsp.window.move({ workspace = "special:" .. name, follow = true })
  )
  hl.bind(
    mainMod .. " + ALT + " .. key,
    hl.dsp.window.move({ workspace = "special:" .. name, follow = false })
  )
  hl.bind(mainMod .. " + " .. key, hl.dsp.workspace.toggle_special(name))
end

bindSpecialWorkspace("S", "S")
bindSpecialWorkspace("M", "M")

-- 屏幕捕获。
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("hypr-screenshot area"))
hl.bind(mainMod .. " + CTRL + P", hl.dsp.exec_cmd("hypr-screenshot area true"))
hl.bind(mainMod .. " + ALT + P", hl.dsp.exec_cmd("hypr-screenshot output"))
hl.bind("Print", hl.dsp.exec_cmd("hypr-screenshot screen"))

-- 音量与亮度按键在锁屏时也可用，并支持长按重复。
local mediaFlags = { locked = true, repeating = true }
hl.bind(
  "XF86AudioRaiseVolume",
  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
  mediaFlags
)
hl.bind(
  "XF86AudioLowerVolume",
  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
  mediaFlags
)
hl.bind(
  "XF86AudioMute",
  hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
  mediaFlags
)
hl.bind(
  "XF86MonBrightnessUp",
  hl.dsp.exec_cmd("brightnessctl set 5%+"),
  mediaFlags
)
hl.bind(
  "XF86MonBrightnessDown",
  hl.dsp.exec_cmd("brightnessctl set 5%-"),
  mediaFlags
)

-- Super + 鼠标左/右键移动和调整窗口大小。
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + Z", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + X", hl.dsp.window.resize(), { mouse = true })
