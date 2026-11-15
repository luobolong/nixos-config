#!/usr/bin/env bash
# Hyprland can leave Fcitx's text-input focus on the previous window while
# Noctalia's launcher owns keyboard focus. Use Latin until dismissal.

launcher_is_open() {
  noctalia msg status 2>/dev/null |
    jq -e '.panelOpen and .activePanelId == "launcher"' >/dev/null
}

# A second shortcut/click closes the panel. The first invocation owns the
# saved input-method state and restores it when the panel closes.
exec 9>"${XDG_RUNTIME_DIR:?}/noctalia-launcher-latin.lock"
if ! flock -n 9; then
  exec noctalia msg panel-close launcher
fi

if launcher_is_open; then
  exec noctalia msg panel-close launcher
fi

previous_state=$(fcitx5-remote --check 2>/dev/null || true)
case "$previous_state" in
  1 | 2) ;;
  *) exec noctalia msg panel-open launcher ;;
esac

restore_input_method() {
  if [[ "$previous_state" == 2 ]]; then
    fcitx5-remote --check -o >/dev/null 2>&1 || true
  fi
}
trap restore_input_method EXIT
trap 'exit 0' HUP INT TERM

fcitx5-remote --check -c
noctalia msg panel-open launcher

# Wait for the asynchronous panel-open request to become visible.
opened=false
for ((attempt = 0; attempt < 20; attempt++)); do
  if launcher_is_open; then
    opened=true
    break
  fi
  sleep 0.05
done
if [[ "$opened" != true ]]; then
  exit 0
fi

while launcher_is_open; do
  # Stay in Latin if the input-method shortcut is pressed in the panel.
  if [[ "$(fcitx5-remote --check 2>/dev/null || true)" == 2 ]]; then
    fcitx5-remote --check -c
  fi
  sleep 0.1
done
