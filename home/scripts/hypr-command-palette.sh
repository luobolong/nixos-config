# shellcheck shell=bash
entries="$(@coreutils@/bin/printf '%s\n' \
  $'close\tWindow  ·  SUPER + Q / ALT + F4  ·  Close the active window' \
  $'force-kill\tWindow  ·  SUPER + ALT + F4  ·  Force-kill the active window' \
  $'float\tWindow  ·  SUPER + W  ·  Toggle floating' \
  $'group\tWindow  ·  SUPER + G  ·  Toggle grouping' \
  $'pin\tWindow  ·  SUPER + SHIFT + W  ·  Toggle floating and pinning' \
  $'fullscreen\tWindow  ·  SUPER + D / SHIFT + F11  ·  Toggle fullscreen' \
  $'maximize\tWindow  ·  SUPER + M  ·  Toggle maximized' \
  $'split\tWindow  ·  SUPER + J  ·  Toggle Dwindle split direction' \
  $'group-prev\tWindow  ·  SUPER + CTRL + H  ·  Previous window in group' \
  $'group-next\tWindow  ·  SUPER + CTRL + L  ·  Next window in group' \
  $'window-overview\tWindow  ·  ALT + Tab  ·  Open Noctalia window overview' \
  $'zoom-toggle\tAccessibility  ·  SUPER + ALT + Z  ·  Toggle 2x screen magnification' \
  $'zoom-adjust\tAccessibility  ·  SUPER + ALT + Wheel  ·  Adjust screen magnification' \
  $'focus-left\tFocus  ·  SUPER + Left  ·  Focus left' \
  $'focus-right\tFocus  ·  SUPER + Right  ·  Focus right' \
  $'focus-up\tFocus  ·  SUPER + Up  ·  Focus up' \
  $'focus-down\tFocus  ·  SUPER + Down  ·  Focus down' \
  $'move-left\tWindow  ·  SUPER + CTRL + SHIFT + Left  ·  Move left' \
  $'move-right\tWindow  ·  SUPER + CTRL + SHIFT + Right  ·  Move right' \
  $'move-up\tWindow  ·  SUPER + CTRL + SHIFT + Up  ·  Move up' \
  $'move-down\tWindow  ·  SUPER + CTRL + SHIFT + Down  ·  Move down' \
  $'resize-left\tWindow  ·  SUPER + SHIFT + Left  ·  Shrink horizontally' \
  $'resize-right\tWindow  ·  SUPER + SHIFT + Right  ·  Grow horizontally' \
  $'resize-up\tWindow  ·  SUPER + SHIFT + Up  ·  Shrink vertically' \
  $'resize-down\tWindow  ·  SUPER + SHIFT + Down  ·  Grow vertically' \
  $'terminal\tApplication  ·  SUPER + T  ·  Open terminal' \
  $'files\tApplication  ·  SUPER + E  ·  Open file manager' \
  $'editor\tApplication  ·  SUPER + C  ·  Open VS Code' \
  $'browser\tApplication  ·  SUPER + B / F  ·  Open Firefox' \
  $'monitor\tApplication  ·  CTRL + SHIFT + Escape  ·  Open system monitor' \
  $'launcher\tApplication  ·  SUPER + A  ·  Open application launcher' \
  $'clipboard\tApplication  ·  SUPER + V  ·  Open Noctalia clipboard' \
  $'lock\tSystem  ·  SUPER + L  ·  Lock the screen' \
  $'workspace-empty\tWorkspace  ·  SUPER + CTRL + Down  ·  Switch to an empty workspace' \
  $'workspace-next-existing\tWorkspace  ·  SUPER + Wheel Down  ·  Next existing workspace' \
  $'workspace-prev-existing\tWorkspace  ·  SUPER + Wheel Up  ·  Previous existing workspace' \
  $'workspace-next\tWorkspace  ·  SUPER + CTRL + Right  ·  Next relative workspace' \
  $'workspace-prev\tWorkspace  ·  SUPER + CTRL + Left  ·  Previous relative workspace' \
  $'move-workspace-next\tWorkspace  ·  SUPER + ALT + CTRL + Right  ·  Move window to next workspace' \
  $'move-workspace-prev\tWorkspace  ·  SUPER + ALT + CTRL + Left  ·  Move window to previous workspace' \
  $'special-s\tWorkspace  ·  SUPER + S  ·  Toggle special workspace S' \
  $'move-special-s\tWorkspace  ·  SUPER + SHIFT + S  ·  Move window to S and follow' \
  $'move-special-s-silent\tWorkspace  ·  SUPER + ALT + S  ·  Move window silently to S' \
  $'picker\tCapture  ·  SUPER + SHIFT + P  ·  Pick a color' \
  $'screenshot-area\tCapture  ·  SUPER + P  ·  Capture a screen region' \
  $'screenshot-freeze\tCapture  ·  SUPER + CTRL + P  ·  Freeze and capture a screen region' \
  $'screenshot-output\tCapture  ·  SUPER + ALT + P  ·  Capture the current display' \
  $'screenshot-screen\tCapture  ·  Print  ·  Capture all displays' \
  $'volume-up\tMedia  ·  Volume Up  ·  Raise volume by 5%' \
  $'volume-down\tMedia  ·  Volume Down  ·  Lower volume by 5%' \
  $'volume-mute\tMedia  ·  Mute  ·  Toggle mute' \
  $'brightness-up\tMedia  ·  Brightness Up  ·  Raise brightness by 5%' \
  $'brightness-down\tMedia  ·  Brightness Down  ·  Lower brightness by 5%' \
  $'workspace-1\tWorkspace  ·  SUPER + 1  ·  Switch to workspace 1' \
  $'workspace-2\tWorkspace  ·  SUPER + 2  ·  Switch to workspace 2' \
  $'workspace-3\tWorkspace  ·  SUPER + 3  ·  Switch to workspace 3' \
  $'workspace-4\tWorkspace  ·  SUPER + 4  ·  Switch to workspace 4' \
  $'workspace-5\tWorkspace  ·  SUPER + 5  ·  Switch to workspace 5' \
  $'workspace-6\tWorkspace  ·  SUPER + 6  ·  Switch to workspace 6' \
  $'workspace-7\tWorkspace  ·  SUPER + 7  ·  Switch to workspace 7' \
  $'workspace-8\tWorkspace  ·  SUPER + 8  ·  Switch to workspace 8' \
  $'workspace-9\tWorkspace  ·  SUPER + 9  ·  Switch to workspace 9' \
  $'workspace-10\tWorkspace  ·  SUPER + 0  ·  Switch to workspace 10' \
  $'move-workspace-1\tWorkspace  ·  SUPER + SHIFT + 1  ·  Move window to workspace 1' \
  $'move-workspace-2\tWorkspace  ·  SUPER + SHIFT + 2  ·  Move window to workspace 2' \
  $'move-workspace-3\tWorkspace  ·  SUPER + SHIFT + 3  ·  Move window to workspace 3' \
  $'move-workspace-4\tWorkspace  ·  SUPER + SHIFT + 4  ·  Move window to workspace 4' \
  $'move-workspace-5\tWorkspace  ·  SUPER + SHIFT + 5  ·  Move window to workspace 5' \
  $'move-workspace-6\tWorkspace  ·  SUPER + SHIFT + 6  ·  Move window to workspace 6' \
  $'move-workspace-7\tWorkspace  ·  SUPER + SHIFT + 7  ·  Move window to workspace 7' \
  $'move-workspace-8\tWorkspace  ·  SUPER + SHIFT + 8  ·  Move window to workspace 8' \
  $'move-workspace-9\tWorkspace  ·  SUPER + SHIFT + 9  ·  Move window to workspace 9' \
  $'move-workspace-10\tWorkspace  ·  SUPER + SHIFT + 0  ·  Move window to workspace 10'
)"

choice="$(
  @coreutils@/bin/printf '%s\n' "$entries" | fuzzel \
    --dmenu \
    --only-match \
    --no-sort \
    --with-nth=2 \
    --accept-nth=1 \
    --match-nth=2 \
    --prompt='⌕  ' \
    --placeholder='Search shortcuts, applications, or actions…' \
    --lines=16 \
    --width=72 \
    --font='Inter:size=12' \
    --counter \
    --border-radius=14 \
    --selection-radius=8 \
    --inner-pad=8 \
    --horizontal-pad=24 \
    --vertical-pad=10
)" || exit 0

dispatch() {
  hyprctl --quiet dispatch "$@"
}

case "$choice" in
  close) dispatch killactive ;;
  force-kill) dispatch forcekillactive ;;
  float) dispatch togglefloating ;;
  group) dispatch togglegroup ;;
  pin) dispatch setfloating; dispatch pin ;;
  fullscreen) dispatch fullscreen 0 ;;
  maximize) dispatch fullscreen 1 ;;
  split) dispatch layoutmsg togglesplit ;;
  group-prev) dispatch changegroupactive b ;;
  group-next) dispatch changegroupactive f ;;
  window-overview) noctalia msg window-switcher ;;
  focus-left) dispatch movefocus l ;;
  focus-right) dispatch movefocus r ;;
  focus-up) dispatch movefocus u ;;
  focus-down) dispatch movefocus d ;;
  move-left) dispatch movewindow l ;;
  move-right) dispatch movewindow r ;;
  move-up) dispatch movewindow u ;;
  move-down) dispatch movewindow d ;;
  resize-left) dispatch resizeactive -50 0 ;;
  resize-right) dispatch resizeactive 50 0 ;;
  resize-up) dispatch resizeactive 0 -50 ;;
  resize-down) dispatch resizeactive 0 50 ;;
  terminal) dispatch exec kitty ;;
  files) dispatch exec dolphin ;;
  editor) dispatch exec code ;;
  browser) dispatch exec firefox ;;
  monitor) dispatch exec missioncenter ;;
  launcher) noctalia msg panel-toggle launcher ;;
  clipboard) noctalia msg panel-toggle clipboard ;;
  lock) dispatch exec hyprlock ;;
  workspace-empty) dispatch workspace empty ;;
  workspace-next-existing) dispatch workspace 'e+1' ;;
  workspace-prev-existing) dispatch workspace 'e-1' ;;
  workspace-next) dispatch workspace 'r+1' ;;
  workspace-prev) dispatch workspace 'r-1' ;;
  move-workspace-next) dispatch movetoworkspace 'r+1' ;;
  move-workspace-prev) dispatch movetoworkspace 'r-1' ;;
  special-s) dispatch togglespecialworkspace S ;;
  move-special-s) dispatch movetoworkspace special:S ;;
  move-special-s-silent) dispatch movetoworkspacesilent special:S ;;
  picker) dispatch exec 'hyprpicker -a' ;;
  screenshot-area) dispatch exec 'screenshot area' ;;
  screenshot-freeze) dispatch exec 'screenshot area true' ;;
  screenshot-output) dispatch exec 'screenshot output' ;;
  screenshot-screen) dispatch exec 'screenshot screen' ;;
  volume-up) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ ;;
  volume-down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
  volume-mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
  brightness-up) brightnessctl set 5%+ ;;
  brightness-down) brightnessctl set 5%- ;;
  workspace-*) dispatch workspace "${choice#workspace-}" ;;
  move-workspace-*) dispatch movetoworkspace "${choice#move-workspace-}" ;;
esac
