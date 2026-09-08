export VIRTUAL_ENV_DISABLE_PROMPT=1
FUNCNEST=100

lf() {
  local tmp dir
  tmp=$(mktemp) || return
  command lf -last-dir-path="$tmp" "$@"
  if [[ -f "$tmp" ]]; then
    dir=$(command cat "$tmp")
    command rm -f "$tmp"
    [[ -d "$dir" && "$dir" != "$PWD" ]] && cd "$dir"
  fi
}
