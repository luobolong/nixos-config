# shellcheck shell=bash
# Move or resize a floating window; otherwise navigate the tiled layout.

operation="${1:-}"
direction="${2:-}"
amount="${3:-50}"

case "$operation" in
    move | resize) ;;
    *)
        echo "usage: niri-smart-direction <move|resize> <left|right|up|down> [pixels]" >&2
        exit 2
        ;;
esac

case "$direction" in
    left | right | up | down) ;;
    *)
        echo "usage: niri-smart-direction <move|resize> <left|right|up|down> [pixels]" >&2
        exit 2
        ;;
esac

if [[ ! "$amount" =~ ^[1-9][0-9]*$ ]]; then
    echo "pixels must be a positive integer" >&2
    exit 2
fi

focused_state="$(
    niri msg --json focused-window | jq -r '
        if type == "object" then
            [(.is_floating // false), (.id // "")]
        else
            [false, ""]
        end
        | @tsv
    '
)"
IFS=$'\t' read -r is_floating window_id <<< "$focused_state"

if [[ "$is_floating" == "true" && -n "$window_id" ]]; then
    case "$direction" in
        left)
            axis="x"
            delta="-$amount"
            ;;
        right)
            axis="x"
            delta="+$amount"
            ;;
        up)
            axis="y"
            delta="-$amount"
            ;;
        down)
            axis="y"
            delta="+$amount"
            ;;
    esac

    if [[ "$operation" == "move" ]]; then
        niri msg action move-floating-window --id "$window_id" "--$axis" "$delta"
    else
        case "$axis" in
            x) dimension="width" ;;
            y) dimension="height" ;;
        esac
        niri msg action "set-window-$dimension" --id "$window_id" "$delta"
    fi
elif [[ "$operation" == "resize" ]]; then
    niri msg action "focus-monitor-$direction"
else
    case "$direction" in
        left | right) niri msg action "focus-column-$direction" ;;
        up | down) niri msg action "focus-window-$direction" ;;
    esac
fi
