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
    sensitivity = -0.5,
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
  cursor = {
    -- Keep the zoom camera attached to the pointer and follow it rigidly, so
    -- the pointer stays centered while the magnified viewport moves with it.
    zoom_detached_camera = false,
    zoom_rigid = true,
  },
  binds = {
    -- Consume every bound wheel event. A nonzero scroll delay lets events
    -- arriving during the delay pass through to the focused application.
    pass_mouse_when_bound = false,
    scroll_event_delay = 0,
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
      -- Blur the complete workspace behind an opened special workspace.
      special = true,
    },
  },
  animations = {
    enabled = true,
  },
  dwindle = {
    preserve_split = true,
  },
})

-- Noctalia publishes an ext-background-effect blur region for its bar. A
-- window_rule cannot match that layer-shell surface, so scope the layer rule
-- to Noctalia's bar namespace. `ignore_alpha = 1.0` also suppresses the
-- protocol blur over transparent and translucent bar pixels.
hl.layer_rule({
  name = "noctalia-bar-transparent",
  match = { namespace = "^noctalia-bar-.+$" },
  blur = false,
  blur_popups = false,
  ignore_alpha = 1.0,
})

-- Let maximized windows reach the working-area edges while keeping panels
-- visible. The regular 5/10 gaps return automatically after unmaximizing.
hl.workspace_rule({
  workspace = "f[1]",
  gaps_in = 0,
  gaps_out = 0,
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
  match = { class = "^(kitty|org[.]kde[.]dolphin)$" },
  opacity = "0.90 override 0.78 override 1.0 override",
  no_blur = false,
})

-- Keep the system monitor as a centered utility window.
hl.window_rule({
  name = "mission-center-float",
  match = { class = "^io[.]missioncenter[.]MissionCenter$" },
  float = true,
  center = true,
})

-- QQ reuses the same class for its main window and image viewer, so also
-- match the viewer's title to keep only that utility window floating.
hl.window_rule({
  name = "qq-image-viewer-float",
  match = { class = "^QQ$", title = "^图片查看器$" },
  float = true,
})

-- Recent Firefox versions initially expose the Bitwarden pop-out as a generic
-- Firefox window and only add the extension name later. React to that title
-- change so static-rule timing cannot leave the pop-out tiled.
local centeredBitwardenPopouts = {}

local function centerBitwardenPopout(window)
  local stableId = window and window.stable_id
  if stableId == nil or window.class ~= "firefox" or centeredBitwardenPopouts[stableId] then
    return
  end

  local title = string.lower(window.title or "")
  local isBitwardenPopout = title == "bitwarden"
    or (
      string.find(title, "extension:", 1, true) ~= nil
      and string.find(title, "bitwarden", 1, true) ~= nil
    )

  if not isBitwardenPopout then
    return
  end

  centeredBitwardenPopouts[stableId] = true
  hl.dispatch(hl.dsp.window.float({ action = "set", window = window }))
  hl.dispatch(hl.dsp.window.center({ window = window }))
end

hl.on("window.open", centerBitwardenPopout)
hl.on("window.title", centerBitwardenPopout)
hl.on("window.destroy", function(window)
  local stableId = window and window.stable_id
  if stableId ~= nil then
    centeredBitwardenPopouts[stableId] = nil
  end
end)

-- Window and session actions.
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind(mainMod .. " + ALT + F4", hl.dsp.window.kill())
hl.bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind("SHIFT + F11", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + D", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + W", function()
  hl.dispatch(hl.dsp.window.float({ action = "set" }))
  hl.dispatch(hl.dsp.window.pin({ action = "toggle" }))
end)
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + CTRL + H", hl.dsp.group.prev())
hl.bind(mainMod .. " + CTRL + L", hl.dsp.group.next())
hl.bind("ALT + Tab", hl.dsp.exec_cmd("noctalia msg window-switcher"))

local function setZoom(targetZoom)
  hl.config({ cursor = { zoom_factor = math.min(10, math.max(1, targetZoom)) } })
end

local function adjustZoom(delta)
  local currentZoom = tonumber(hl.get_config("cursor.zoom_factor")) or 1
  setZoom(currentZoom + delta)
end

-- Toggle Hyprland's built-in cursor-centered magnifier at 2x zoom, or adjust
-- it in 0.25x steps while Super+Alt is held.
hl.bind(mainMod .. " + ALT + Z", function()
  local currentZoom = tonumber(hl.get_config("cursor.zoom_factor")) or 1
  setZoom(currentZoom > 1 and 1 or 2)
end)
hl.bind(
  mainMod .. " + ALT + mouse_up",
  function()
    adjustZoom(0.25)
  end,
  { non_consuming = false }
)
hl.bind(
  mainMod .. " + ALT + mouse_down",
  function()
    adjustZoom(-0.25)
  end,
  { non_consuming = false }
)

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

-- Frequently used applications.
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("firefox"))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("missioncenter"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"))
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd("hypr-command-palette"))

-- Workspaces 1–10; digit key 0 maps to workspace 10.
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

-- Screen capture (shared with niri).
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("screenshot area"))
hl.bind(mainMod .. " + CTRL + P", hl.dsp.exec_cmd("screenshot area true"))
hl.bind(mainMod .. " + ALT + P", hl.dsp.exec_cmd("screenshot output"))
hl.bind("Print", hl.dsp.exec_cmd("screenshot screen"))

-- Volume and brightness keys remain available while locked and support
-- press-and-hold repeating.
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

-- Super + left/right mouse button moves or resizes windows.
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + Z", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + X", hl.dsp.window.resize(), { mouse = true })
