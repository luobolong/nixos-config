# shellcheck shell=bash
# Main configs keep their managed includes; disable only the generated palette.
set -euo pipefail
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
case "$1" in
  kitty) theme_file="$config_dir/kitty/themes/noctalia.conf" ;;
  niri) theme_file="$config_dir/niri/noctalia.kdl" ;;
  mango) theme_file="$config_dir/mango/noctalia.conf" ;;
  hyprland)
    if [[ -f "$config_dir/hypr/noctalia.lua" ]]; then
      printf 'return { apply_theme = function() end }\n' > "$config_dir/hypr/noctalia.lua"
    fi
    if [[ -f "$config_dir/hypr/noctalia.conf" ]]; then
      : > "$config_dir/hypr/noctalia.conf"
    fi
    exit 0
    ;;
  *) exit 2 ;;
esac

# Avoid signaling applications when the template was already inactive.
[[ -s "$theme_file" ]] || exit 0
: > "$theme_file"
case "$1" in
  kitty) pkill -USR1 -u "$(id -u)" -x 'kitty|\.kitty-wrapped' 2>/dev/null || true ;;
  mango) mmsg dispatch reload_config 2>/dev/null || true ;;
esac
