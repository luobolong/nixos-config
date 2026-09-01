{
  config,
  lib,
  pkgs,
  ...
}:
let
  fzfPreviewCommand = "bat --color=always --style=plain,numbers --line-range=:500 {}";
in
{
  home.sessionVariables.MANPAGER = "bat -l man -p";

  # programs.starship declares its generated config through home.file using
  # this absolute XDG path. Force that same entry so a stale fixed-suffix
  # backup cannot block later activations.
  home.file."${config.xdg.configHome}/starship.toml".force = true;

  programs = {
    bat.enable = true;

    eza = {
      enable = true;
      enableZshIntegration = false;
    };

    fzf = {
      enable = true;
      enableZshIntegration = false;
      defaultCommand = "fd --type f --hidden --strip-cwd-prefix";
      defaultOptions = [
        "--height=60%"
        "--layout=reverse"
        "--border=rounded"
        "--prompt='  '"
        "--pointer='  '"
        "--preview-window=right:65%:wrap:border-left"
      ];
      fileWidget = {
        command = "fd --type f --hidden --strip-cwd-prefix";
        options = [ "--preview '${fzfPreviewCommand}'" ];
      };
    };

    lf.enable = true;

    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      dotDir = "${config.xdg.configHome}/zsh";
      autocd = true;

      autosuggestion.enable = true;
      fastSyntaxHighlighting.enable = true;

      history = {
        path = "${config.xdg.stateHome}/zsh/history";
        size = 100000;
        save = 100000;
        append = true;
        share = true;
        ignoreDups = true;
        ignoreSpace = true;
        expireDuplicatesFirst = true;
        findNoDups = true;
      };

      setOptions = [
        "NO_BEEP"
        "NUMERIC_GLOB_SORT"
      ];

      completionInit = ''
        autoload -Uz compinit
        mkdir -p "${config.xdg.cacheHome}/zsh"
        compinit -d "${config.xdg.cacheHome}/zsh/zcompdump"
        zstyle ':completion:*' menu select
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
        compdef eza=ls
      '';

      shellAliases = {
        ls = "eza --icons";
        ll = "eza -lh --icons --git";
        la = "eza -lah --icons --git";
        tree = "eza --tree --icons";
        cat = "bat";
        grep = "rg --color=auto";
        diff = "diff --color=auto";
        df = "df -h";
        "-" = "cd -";
        vim = "nvim";
        glog = ''PAGER="less -F -X" git log'';
        gadog = ''PAGER="less -F -X" git log --all --decorate --oneline --graph'';
        dotfiles = "git --git-dir=$HOME/.dotfiles --work-tree=$HOME";
        stream = "mpv av://v4l2:/dev/video4 --fullscreen --demuxer-lavf-o=input_format=mjpeg,framerate=30 --profile=low-latency --untimed";
      };

      plugins = [
        {
          name = "zsh-history-substring-search";
          src = pkgs.zsh-history-substring-search;
          file = "share/zsh-history-substring-search/zsh-history-substring-search.zsh";
        }
        {
          name = "zsh-vi-mode";
          src = pkgs.zsh-vi-mode;
          file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
        }
      ];

      initContent = lib.mkMerge [
        # Load fzf before zsh-vi-mode, matching the upstream configuration.
        (lib.mkOrder 800 ''
          if [[ $options[zle] = on ]]; then
            source <(${lib.getExe pkgs.fzf} --zsh)
          fi
        '')

        # zsh-vi-mode resets bindings while it initializes, so register them
        # through its hook before Home Manager sources the plugin.
        (lib.mkOrder 850 ''
          export _FZF_PREVIEW_CMD='${fzfPreviewCommand}'

          _fzf_file_no_hidden() {
            local cmd result
            cmd="''${FZF_DEFAULT_COMMAND/--hidden /}"
            result=$(eval "''${cmd:-find . -type f}" | fzf --preview "$_FZF_PREVIEW_CMD") \
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
        '')

        (lib.mkOrder 950 ''
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
        '')
      ];
    };

    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        "$schema" = "https://starship.rs/config-schema.json";
        add_newline = false;
        format = "$os$directory$git_branch$git_status$nodejs$rust$golang$php$character";

        os = {
          disabled = false;
          format = "[$symbol](#blue) ";
          symbols = {
            Ubuntu = "󰕈";
            Artix = "󰣇";
            Arch = "󰣇";
            CachyOS = "󰣇";
            Macos = "";
            NixOS = "󱄅";
          };
        };

        directory = {
          format = "[$path](cyan) ";
          truncation_length = 4;
          truncate_to_repo = true;
        };

        git_branch = {
          symbol = "";
          format = "[$symbol $branch](bold purple) ";
        };

        git_status = {
          format = "($ahead_behind$staged$modified$untracked$deleted$conflicted)";
          ahead = "[⇡$count ](bold cyan)";
          behind = "[⇣$count ](bold cyan)";
          diverged = "[⇡$ahead_count⇣$behind_count ](bold cyan)";
          staged = "[+$count ](bold green)";
          modified = "[●$count ](bold yellow)";
          untracked = "[?$count ](bold white)";
          deleted = "[✘$count ](bold red)";
          conflicted = "[⚡$count ](bold red)";
        };

        nodejs = {
          symbol = "";
          format = "[$symbol $version](green) ";
        };
        rust = {
          symbol = "";
          format = "[$symbol $version](red) ";
        };
        golang = {
          symbol = "";
          format = "[$symbol $version](cyan) ";
        };
        php = {
          symbol = "";
          format = "[$symbol $version](purple) ";
        };

        character = {
          success_symbol = "[❯](green)";
          error_symbol = "[❯](red)";
          vimcmd_symbol = "[❮](blue)";
        };
      };
    };
  };
}
