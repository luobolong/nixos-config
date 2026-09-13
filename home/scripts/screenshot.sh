# shellcheck shell=bash
# Shared screenshot workflow for Hyprland and niri.
# Capture/copy/annotate workflow inspired by HyDE's screenshot.sh:
# https://github.com/HyDE-Project/HyDE/blob/master/Configs/.local/lib/hyde/screenshot.sh
usage() {
  cat <<'EOF'
Usage: screenshot [area|window|output|screen] [true|false] [options]
       screenshot [s|sf|m|p] [options]

Automatically selects the backend for the current Hyprland or niri session.

  area, s    Select a region (or click a window in Hyprland)
  window     Pick a window (niri); select a window or region (Hyprland)
  sf         Freeze the screen, then select a region
  output, m  Capture the focused monitor
  screen, p  Capture all monitors
  true       Freeze before selecting an area (legacy second argument)

  --no-annotate  Copy and save directly without opening Satty
  --no-notify    Disable screenshot notifications
  -h, --help    Show this help
EOF
}

annotate="${SCREENSHOT_ANNOTATION_ENABLED:-true}"
notify="${SCREENSHOT_NOTIFY:-true}"
positional=()
for argument in "$@"; do
  case "$argument" in
    --no-annotate) annotate=false ;;
    --no-notify) notify=false ;;
    -h|--help) usage; exit 0 ;;
    *) positional+=("$argument") ;;
  esac
done
if (( ${#positional[@]} > 2 )); then
  usage >&2
  exit 2
fi

target="${positional[0]:-area}"
freeze="${positional[1]:-false}"
case "$freeze" in
  true|false) ;;
  *) usage >&2; exit 2 ;;
esac
case "$target" in
  area|s|snip) target=area ;;
  window) ;;
  sf|snapfreeze) target=area; freeze=true ;;
  output|m|monitor) target=output ;;
  screen|p|printscreen) target=screen ;;
  *) usage >&2; exit 2 ;;
esac

report_error() {
  echo "screenshot: $1" >&2
  if [[ "$notify" != false ]]; then
    notify-send -a Screenshot -u critical "Screenshot failed" "$1" || true
  fi
  exit 1
}

pictures="${XDG_PICTURES_DIR:-}"
if [[ -z "$pictures" ]]; then
  pictures="$(xdg-user-dir PICTURES)"
fi
directory="${pictures:-$HOME/Pictures}/Screenshots"
mkdir -p "$directory"
file="$directory/$(date +'%Y-%m-%d_%H-%M-%S-%N').png"
raw_file="$(mktemp --suffix=.png)"
freeze_pid=""
event_pid=""

unfreeze() {
  if [[ -n "$freeze_pid" ]]; then
    kill "$freeze_pid" 2>/dev/null || true
    wait "$freeze_pid" 2>/dev/null || true
    freeze_pid=""
  fi
}

cleanup() {
  unfreeze
  if [[ -n "$event_pid" ]]; then
    kill "$event_pid" 2>/dev/null || true
    wait "$event_pid" 2>/dev/null || true
    exec {event_fd}<&-
  fi
  rm -f "$raw_file"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

if [[ -n "${NIRI_SOCKET:-}" ]]; then
  case "$target" in
    window)
      picked_window="$(niri msg --json pick-window)" \
        || report_error "Could not select a window."
      # Escape or a click outside a window returns null; never fall back to
      # the focused window when the user cancels the picker.
      window_id="$(jq -er '.id // empty' <<< "$picked_window")" || exit 0

      # Screenshot actions return before PNG encoding and saving finishes.
      # Subscribe first and wait for the initial event to avoid missing the
      # completion event, then match this capture's unique temporary path.
      exec {event_fd}< <(niri msg --json event-stream)
      event_pid=$!
      IFS= read -r -t 10 -u "$event_fd" event \
        || report_error "Could not listen for screenshot completion."
      niri msg action screenshot-window --id "$window_id" --path "$raw_file" \
        || report_error "Could not capture the selected window."
      deadline=$((SECONDS + 10))
      captured=false
      while (( SECONDS < deadline )) && \
        IFS= read -r -t "$((deadline - SECONDS))" -u "$event_fd" event; do
        if jq -e --arg path "$raw_file" '.ScreenshotCaptured.path == $path' \
          <<< "$event" >/dev/null; then
          captured=true
          break
        fi
      done
      [[ "$captured" == true && -s "$raw_file" ]] \
        || report_error "Timed out waiting for the window screenshot."
      kill "$event_pid" 2>/dev/null || true
      wait "$event_pid" 2>/dev/null || true
      event_pid=""
      exec {event_fd}<&-
      ;;
    area)
      if [[ "$freeze" == "true" ]]; then
        wayfreeze --hide-cursor &
        freeze_pid=$!
        sleep 0.1
        kill -0 "$freeze_pid" 2>/dev/null || report_error "Could not freeze the screen."
      fi

      geometry="$(slurp)" || exit 0
      [[ -n "$geometry" ]] || exit 0
      grim -g "$geometry" "$raw_file"
      ;;
    output)
      output="$(niri msg --json focused-output | jq -er '.name')"
      grim -o "$output" "$raw_file"
      ;;
    screen)
      grim "$raw_file"
      ;;
  esac
else
  # Grimblast already includes window picking in its area selector.
  [[ "$target" != window ]] || target=area
  args=()
  if [[ "$freeze" == "true" ]]; then
    args+=(--freeze)
  fi

  grimblast "${args[@]}" save "$target" "$raw_file"
fi

unfreeze
# Some capture backends return successfully when selection is cancelled.
[[ -s "$raw_file" ]] || exit 0
wl-copy --type image/png < "$raw_file" || report_error "Could not copy the screenshot."

if [[ "$annotate" == false ]]; then
  cp "$raw_file" "$file"
else
  annotation_args=(--filename "$raw_file" --output-filename "$file")
  if [[ "$notify" == false ]]; then
    annotation_args+=(--disable-notifications)
  fi
  # HyDE uses GL to avoid GTK renderer issues; honor explicit overrides.
  GSK_RENDERER="${GSK_RENDERER:-gl}" satty "${annotation_args[@]}" \
    || report_error "Could not open Satty; the screenshot is still in the clipboard."
fi

if [[ -s "$file" && "$notify" != false ]]; then
  notify-send -a Screenshot -i "$file" "Screenshot saved" "$file" || true
fi
