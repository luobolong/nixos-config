export _FZF_PREVIEW_CMD='@fzfPreviewCommand@'

_fzf_file_no_hidden() {
  local cmd result
  cmd="${FZF_DEFAULT_COMMAND/--hidden /}"
  result=$(eval "${cmd:-find . -type f}" | fzf --preview "$_FZF_PREVIEW_CMD") \
    && LBUFFER+="$result"
  zle reset-prompt
}
zle -N _fzf_file_no_hidden

ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BEAM
ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
ZVM_VI_HIGHLIGHT_BACKGROUND=none
ZVM_VI_HIGHLIGHT_FOREGROUND=none
ZVM_VI_HIGHLIGHT_EXTRASTYLE=none

zvm_after_init() {
  bindkey '^[[1;5C' forward-word
  bindkey '^[[1;5D' backward-word
  # zsh-vi-mode assigns Ctrl+R to its own history widget.
  bindkey '^R' fzf-history-widget
  bindkey '^F' _fzf_file_no_hidden
  bindkey '^\' autosuggest-toggle
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
}
