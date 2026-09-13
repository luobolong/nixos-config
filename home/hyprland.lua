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
    sensitivity = -0.6,
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

-- 1. 窗口与会话 / Windows and session
hl.bind(
  mainMod .. " + Q",
  hl.dsp.window.close(),
  { description = "关闭当前窗口 / Close window" }
)
hl.bind("ALT + F4", hl.dsp.window.close(), { description = "关闭当前窗口 / Close window" })
hl.bind(
  mainMod .. " + ALT + F4",
  hl.dsp.window.kill(),
  { description = "强制结束当前窗口 / Force kill window" }
)
hl.bind(
  mainMod .. " + W",
  hl.dsp.window.float({ action = "toggle" }),
  { description = "切换窗口浮动 / Toggle floating" }
)
hl.bind(
  mainMod .. " + G",
  hl.dsp.group.toggle(),
  { description = "切换窗口分组 / Toggle grouping" }
)
hl.bind(
  mainMod .. " + L",
  hl.dsp.exec_cmd("hyprlock"),
  { description = "锁定屏幕 / Lock screen" }
)
hl.bind(
  "SHIFT + F11",
  hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
  { description = "切换窗口全屏 / Toggle fullscreen" }
)
hl.bind(
  mainMod .. " + D",
  hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
  { description = "切换窗口全屏 / Toggle fullscreen" }
)
hl.bind(
  mainMod .. " + M",
  hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),
  { description = "切换窗口最大化 / Toggle maximize" }
)
hl.bind(mainMod .. " + SHIFT + W", function()
  hl.dispatch(hl.dsp.window.float({ action = "set" }))
  hl.dispatch(hl.dsp.window.pin({ action = "toggle" }))
end, { description = "浮动并切换窗口置顶 / Float and toggle pin" })
hl.bind(
  mainMod .. " + J",
  hl.dsp.layout("togglesplit"),
  { description = "切换平铺分割方向 / Toggle split direction" }
)
hl.bind(
  mainMod .. " + CTRL + H",
  hl.dsp.group.prev(),
  { description = "切换到组内上一个窗口 / Previous grouped window" }
)
hl.bind(
  mainMod .. " + CTRL + L",
  hl.dsp.group.next(),
  { description = "切换到组内下一个窗口 / Next grouped window" }
)
hl.bind(
  "ALT + Tab",
  hl.dsp.exec_cmd("noctalia msg window-switcher"),
  { description = "打开窗口切换器 / Window switcher" }
)

-- 2. 屏幕缩放 / Screen zoom
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
end, { description = "切换两倍屏幕放大 / Toggle 2x zoom" })
hl.bind(mainMod .. " + ALT + mouse_up", function()
  adjustZoom(0.25)
end, { non_consuming = false, description = "增加屏幕放大倍率 / Zoom in" })
hl.bind(mainMod .. " + ALT + mouse_down", function()
  adjustZoom(-0.25)
end, { non_consuming = false, description = "降低屏幕放大倍率 / Zoom out" })

-- 3. 焦点与窗口移动 / Focus and movement
local directionLabels =
  { left = "向左 / Left", right = "向右 / Right", up = "向上 / Up", down = "向下 / Down" }
local directions = {
  left = "l",
  right = "r",
  up = "u",
  down = "d",
}

for key, direction in pairs(directions) do
  hl.bind(
    mainMod .. " + " .. key,
    hl.dsp.focus({ direction = direction }),
    { description = "切换焦点 / Focus：" .. directionLabels[key] }
  )
  hl.bind(
    mainMod .. " + CTRL + SHIFT + " .. key,
    hl.dsp.window.move({ direction = direction }),
    { description = "移动窗口 / Move：" .. directionLabels[key] }
  )
end

-- 4. 窗口大小 / Window size
local resizeLabels = {
  left = "缩小宽度 / Narrower",
  right = "增大宽度 / Wider",
  up = "缩小高度 / Shorter",
  down = "增大高度 / Taller",
}
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
    { repeating = true, description = "调整窗口大小 / Resize：" .. resizeLabels[key] }
  )
end

-- 5. 应用与快捷键帮助 / Applications and help
hl.bind(
  mainMod .. " + T",
  hl.dsp.exec_cmd(terminal),
  { description = "打开终端 Kitty / Open terminal Kitty" }
)
hl.bind(
  mainMod .. " + E",
  hl.dsp.exec_cmd(fileManager),
  { description = "打开文件管理器 Dolphin / Open file manager Dolphin" }
)
hl.bind(
  mainMod .. " + C",
  hl.dsp.exec_cmd("code"),
  { description = "打开编辑器 VS Code / Open editor VS Code" }
)
hl.bind(
  mainMod .. " + B",
  hl.dsp.exec_cmd("firefox"),
  { description = "打开浏览器 Firefox / Open browser Firefox" }
)
hl.bind(
  mainMod .. " + F",
  hl.dsp.exec_cmd("firefox"),
  { description = "打开浏览器 Firefox / Open browser Firefox" }
)
hl.bind(
  "CTRL + SHIFT + Escape",
  hl.dsp.exec_cmd("missioncenter"),
  { description = "打开系统监视器 / System monitor" }
)
hl.bind(
  mainMod .. " + A",
  hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"),
  { description = "打开应用启动器 / Application launcher" }
)
hl.bind(
  mainMod .. " + V",
  hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"),
  { description = "打开剪贴板历史 / Clipboard history" }
)
hl.bind(
  mainMod .. " + slash",
  hl.dsp.exec_cmd("noctalia msg panel-toggle kenn/keybind-cheatsheet:cheatsheet"),
  { description = "打开快捷键速查表 / Keybind cheatsheet" }
)

-- 6. 工作区 / Workspaces
-- Workspaces 1–10; digit key 0 maps to workspace 10.
for workspace = 1, 10 do
  local key = workspace % 10
  hl.bind(
    mainMod .. " + " .. key,
    hl.dsp.focus({ workspace = workspace }),
    { description = "切换到工作区 / Focus workspace " .. workspace }
  )
  hl.bind(
    mainMod .. " + SHIFT + " .. key,
    hl.dsp.window.move({ workspace = workspace, follow = true }),
    { description = "移动并跟随到工作区 / Move and follow to workspace " .. workspace }
  )
end

hl.bind(
  mainMod .. " + CTRL + Down",
  hl.dsp.focus({ workspace = "empty" }),
  { description = "切换到空工作区 / Empty workspace" }
)
local externalPointersOnly = {
  device = { inclusive = false, list = trackpadDevices },
}
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), {
  device = externalPointersOnly.device,
  description = "切换到下一个已有工作区 / Next existing workspace",
})
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), {
  device = externalPointersOnly.device,
  description = "切换到上一个已有工作区 / Previous existing workspace",
})

hl.bind(
  mainMod .. " + CTRL + Right",
  hl.dsp.focus({ workspace = "r+1" }),
  { description = "切换到下一个工作区 / Next workspace" }
)
hl.bind(
  mainMod .. " + CTRL + Left",
  hl.dsp.focus({ workspace = "r-1" }),
  { description = "切换到上一个工作区 / Previous workspace" }
)
hl.bind(
  mainMod .. " + ALT + CTRL + Right",
  hl.dsp.window.move({ workspace = "r+1", follow = true }),
  { description = "移动窗口到下一个工作区并跟随 / Move and follow to next workspace" }
)
hl.bind(
  mainMod .. " + ALT + CTRL + Left",
  hl.dsp.window.move({ workspace = "r-1", follow = true }),
  {
    description = "移动窗口到上一个工作区并跟随 / Move and follow to previous workspace",
  }
)

local function bindSpecialWorkspace(key, name)
  hl.bind(
    mainMod .. " + SHIFT + " .. key,
    hl.dsp.window.move({ workspace = "special:" .. name, follow = true }),
    {
      description = "移入并跟随 / Move and follow to special workspace " .. name,
    }
  )
  hl.bind(
    mainMod .. " + ALT + " .. key,
    hl.dsp.window.move({ workspace = "special:" .. name, follow = false }),
    {
      description = "静默移入 / Move silently to special workspace " .. name,
    }
  )
  hl.bind(
    mainMod .. " + " .. key,
    hl.dsp.workspace.toggle_special(name),
    { description = "切换特殊工作区 / Toggle special workspace " .. name }
  )
end

bindSpecialWorkspace("S", "S")

-- 7. 截图与取色 / Screenshots and colors
-- Screen capture (shared with niri).
hl.bind(
  mainMod .. " + SHIFT + P",
  hl.dsp.exec_cmd("hyprpicker -a"),
  { description = "拾取屏幕颜色 / Color picker" }
)
hl.bind(
  mainMod .. " + P",
  hl.dsp.exec_cmd("screenshot area"),
  { description = "截图：选取区域或窗口 / Screenshot region or window" }
)
hl.bind(mainMod .. " + CTRL + P", hl.dsp.exec_cmd("screenshot area true"), {
  description = "截图：冻结画面后选取区域或窗口 / Screenshot frozen region or window",
})
hl.bind(
  mainMod .. " + ALT + P",
  hl.dsp.exec_cmd("screenshot output"),
  { description = "截图：当前显示器 / Screenshot current display" }
)
hl.bind(
  "Print",
  hl.dsp.exec_cmd("screenshot screen"),
  { description = "截图：所有显示器 / Screenshot all displays" }
)

-- 8. 音量与亮度 / Volume and brightness
-- Volume and brightness keys remain available while locked and support
-- press-and-hold repeating.
hl.bind(
  "XF86AudioRaiseVolume",
  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
  { locked = true, repeating = true, description = "音量增加 5% / Volume up 5%" }
)
hl.bind(
  "XF86AudioLowerVolume",
  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
  { locked = true, repeating = true, description = "音量降低 5% / Volume down 5%" }
)
hl.bind(
  "XF86AudioMute",
  hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
  { locked = true, repeating = true, description = "切换扬声器静音 / Toggle speaker mute" }
)
hl.bind(
  "XF86MonBrightnessUp",
  hl.dsp.exec_cmd("brightnessctl set 5%+"),
  { locked = true, repeating = true, description = "亮度增加 5% / Brightness up 5%" }
)
hl.bind(
  "XF86MonBrightnessDown",
  hl.dsp.exec_cmd("brightnessctl set 5%-"),
  { locked = true, repeating = true, description = "亮度降低 5% / Brightness down 5%" }
)

-- 9. 鼠标拖动 / Mouse dragging
-- Super + left/right mouse button moves or resizes windows.
hl.bind(
  mainMod .. " + mouse:272",
  hl.dsp.window.drag(),
  { mouse = true, description = "拖动窗口 / Drag window" }
)
hl.bind(
  mainMod .. " + mouse:273",
  hl.dsp.window.resize(),
  { mouse = true, description = "拖动调整窗口大小 / Drag to resize window" }
)
hl.bind(
  mainMod .. " + Z",
  hl.dsp.window.drag(),
  { mouse = true, description = "拖动窗口 / Drag window" }
)
hl.bind(
  mainMod .. " + X",
  hl.dsp.window.resize(),
  { mouse = true, description = "拖动调整窗口大小 / Drag to resize window" }
)
