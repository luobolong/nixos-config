# shellcheck shell=bash
# Home Manager declares the include. Only reload Kitty; never touch kitty.conf.
config_file="${XDG_CONFIG_HOME:-$HOME/.config}/kitty/kitty.conf"
if ! grep -Fxq 'include themes/noctalia.conf' "$config_file"; then
  echo "Noctalia: missing managed Kitty theme include in $config_file" >&2
  exit 1
fi
pkill -USR1 -u "$(id -u)" -x 'kitty|\.kitty-wrapped' 2>/dev/null || true
