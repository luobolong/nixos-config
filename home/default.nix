{ config, inputs, lib, pkgs, username, ... }:
let
  flclash = pkgs.callPackage ../packages/flclash.nix { };
  screenshot = pkgs.writeShellApplication {
    name = "hypr-screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      grimblast
    ];
    text = ''
      target="''${1:-area}"
      freeze="''${2:-false}"
      directory="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
      mkdir -p "$directory"
      file="$directory/$(date +'%Y-%m-%d_%H-%M-%S-%N').png"

      args=(--notify)
      if [[ "$freeze" == "true" ]]; then
        args+=(--freeze)
      fi

      grimblast "''${args[@]}" copysave "$target" "$file"
    '';
  };
  togglePinned = pkgs.writeShellApplication {
    name = "hypr-toggle-pin";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      if [[ "$(hyprctl -j activewindow | jq -r '.floating // false')" != "true" ]]; then
        hyprctl dispatch togglefloating
      fi
      hyprctl dispatch pin
    '';
  };
in
{
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
    packages = with pkgs; [
      # 桌面应用
      vscode
      spotify
      flclash
      kdePackages.dolphin
      kdePackages.kio-extras
      firefox
      mission-center
      pavucontrol

      # Hyprland 与 Wayland 桌面工具
      fuzzel
      wl-clipboard
      hyprpicker
      grimblast
      grim
      slurp
      screenshot
      togglePinned
      brightnessctl
      playerctl
      networkmanagerapplet

      # 终端与文件检索工具
      fastfetch
      btop
      ripgrep
      fd
      file
      tree
      which
      lsof

      # 数据处理、传输与归档工具
      jq
      yq-go
      rsync
      zip
      unzip
      p7zip

      # 硬件、存储与网络诊断
      pciutils
      usbutils
      smartmontools
      nvme-cli
      lm_sensors
      dnsutils

      # NixOS 日常维护工具
      nh
      nix-output-monitor
      nvd

      # 开发、构建与语言工具
      cmake
      pkg-config
      shellcheck
      gcc
      gnumake
      nodejs
      python3
      lua-language-server
      nil
      nixfmt-rfc-style
    ];
    preferXdgDirectories = true;
  };

  programs.home-manager.enable = true;
  programs.git.enable = true;
  programs.gpg.enable = true;
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    history.path = "${config.xdg.stateHome}/zsh/history";
  };
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.kitty = {
    enable = true;
    settings = {
      font_family = "JetBrainsMono Nerd Font";
      font_size = 12;
      background_opacity = "0.90";
      dynamic_background_opacity = true;
      confirm_os_window_close = 0;
    };
  };
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    extraPackages = with pkgs; [ tree-sitter ];
  };

  xdg = {
    enable = true;
    terminal-exec = {
      enable = true;
      settings = {
        Hyprland = [ "kitty.desktop" ];
        default = [ "kitty.desktop" ];
      };
    };
    mimeApps = {
      enable = true;
      defaultApplications."inode/directory" = [ "org.kde.dolphin.desktop" ];
    };
    userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = true;
      projects = "${config.home.homeDirectory}/Workspace";
    };
  };
  xdg.configFile."nvim" = {
    source = inputs.astronvim;
    recursive = true;
  };

  # rime-ice 需要在用户目录写入编译产物，因此部署时复制为可写文件。
  home.activation.installRimeIce = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ${config.home.homeDirectory}/.local/share/fcitx5/rime
    $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -rL --chmod=u+w ${inputs.rime-ice}/ ${config.home.homeDirectory}/.local/share/fcitx5/rime/
  '';

  xdg.configFile."fcitx5/profile".text = ''
    [Groups/0]
    Name=Default
    Default Layout=us
    DefaultIM=rime

    [Groups/0/Items/0]
    Name=keyboard-us
    Layout=

    [Groups/0/Items/1]
    Name=rime
    Layout=

    [GroupOrder]
    0=Default
  '';

  xdg.configFile."fcitx5/conf/classicui.conf".text = ''
    # 横向候选列表
    Vertical Candidate List=False

    # 根据各屏幕 DPI 缩放
    PerScreenDPI=True

    Font="Noto Sans 12"
    Theme=catppuccin-mocha-sapphire
  '';

  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    systemd.enable = true;
    settings = {
      "$mod" = "SUPER";
      "$terminal" = "kitty";
      "$fileManager" = "dolphin";
      monitor = ",preferred,auto,1";
      input = {
        kb_layout = "us";
        follow_mouse = 1;
        touchpad.natural_scroll = true;
      };
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        layout = "dwindle";
      };
      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 8;
          passes = 3;
        };
      };
      animations.enabled = true;
      exec-once = [
        "fcitx5 -d --replace"
        "nm-applet --indicator"
        "[workspace special:terminal silent; float; size 80% 50%; center] kitty --class dropdown-terminal --title dropdown-terminal"
      ];
      bind = [
        "$mod, Q, exit"
        "ALT, F4, killactive"
        "$mod, W, togglefloating"
        "$mod, L, exec, hyprlock"
        "SHIFT, F11, fullscreen"
        "$mod, D, fullscreen"
        "$mod SHIFT, F, exec, hypr-toggle-pin"

        "$mod CTRL SHIFT, left, movewindow, l"
        "$mod CTRL SHIFT, right, movewindow, r"
        "$mod CTRL SHIFT, up, movewindow, u"
        "$mod CTRL SHIFT, down, movewindow, d"

        "$mod, T, exec, $terminal"
        "$mod ALT, T, togglespecialworkspace, terminal"
        "$mod, E, exec, $fileManager"
        "$mod, C, exec, code"
        "$mod, B, exec, firefox"
        "CTRL SHIFT, Escape, exec, missioncenter"
        "$mod, A, exec, fuzzel"

        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        "$mod SHIFT, S, movetoworkspace, special:S"
        "$mod ALT, S, movetoworkspacesilent, special:S"
        "$mod, S, togglespecialworkspace, S"
        "$mod SHIFT, M, movetoworkspace, special:M"
        "$mod ALT, M, movetoworkspacesilent, special:M"
        "$mod, M, togglespecialworkspace, M"

        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        "$mod SHIFT, P, exec, hyprpicker -a"
        "$mod, P, exec, hypr-screenshot area"
        "$mod CTRL, P, exec, hypr-screenshot area true"
        "$mod ALT, P, exec, hypr-screenshot output"
        ", Print, exec, hypr-screenshot screen"
      ];
      binde = [
        "$mod SHIFT, right, resizeactive, 50 0"
        "$mod SHIFT, left, resizeactive, -50 0"
        "$mod SHIFT, up, resizeactive, 0 -50"
        "$mod SHIFT, down, resizeactive, 0 50"
      ];
      bindel = [
        ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    # 留空可让 Noctalia 设置界面管理配置；目录已由 impermanence 持久化。
    settings = { };
  };

  services.mako.enable = false;
  services.gpg-agent = {
    enable = true;
    enableZshIntegration = true;
    pinentry.package = pkgs.pinentry-qt;
  };
  services.ssh-agent.enable = true;

  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    TERMINAL = "kitty";
    XMODIFIERS = "@im=fcitx";
  };
}
