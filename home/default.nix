{ config, inputs, lib, osConfig, pkgs, username, ... }:
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
  shortcutsHelpText = pkgs.writeText "hyprland-shortcuts.txt" ''
    Hyprland 快捷键说明
    ==================

    提示：SUPER 是 Windows 键；在此窗口按 q 退出。

    窗口与会话
      SUPER + Q                         退出 Hyprland 会话
      ALT + F4                          关闭当前窗口
      SUPER + W                         切换窗口浮动
      SUPER + SHIFT + W                 先浮动，再切换窗口置顶
      SUPER + L                         锁定屏幕
      SHIFT + F11 / SUPER + D           切换全屏
      SUPER + 方向键                    切换焦点
      SUPER + CTRL + SHIFT + 方向键     向指定方向移动窗口
      SUPER + SHIFT + 方向键            向指定方向调整窗口大小
      SUPER + 鼠标左键                  拖动窗口
      SUPER + 鼠标右键                  调整窗口大小

    常用应用
      SUPER + T                         终端
      SUPER + ALT + T                   切换下拉终端
      SUPER + E                         文件管理器
      SUPER + C                         文本编辑器
      SUPER + B                         浏览器
      CTRL + SHIFT + Escape             系统监视器
      SUPER + A                         应用查找器
      SUPER + /                         打开本说明

    工作区
      SUPER + 1…9 / 0                   切换到工作区 1…9 / 10
      SUPER + SHIFT + 1…9 / 0           移动窗口到工作区 1…9 / 10
      SUPER + S / M                     切换特殊工作区 S / M
      SUPER + SHIFT + S / M             移动窗口到特殊工作区并跟随
      SUPER + ALT + S / M               静默移动窗口到特殊工作区

    屏幕捕获
      SUPER + SHIFT + P                 颜色选择器
      SUPER + P                         截取屏幕区域
      SUPER + CTRL + P                  冻结并截取屏幕区域
      SUPER + ALT + P                   截取当前显示器
      Print                             截取所有显示器

    多媒体
      XF86AudioRaise/LowerVolume        调整音量
      XF86AudioMute                     静音
      XF86MonBrightnessUp/Down          调整屏幕亮度
  '';
  shortcutsHelp = pkgs.writeShellApplication {
    name = "hypr-shortcuts-help";
    runtimeInputs = with pkgs; [
      kitty
      less
    ];
    text = ''
      exec kitty --class shortcuts-help --title "快捷键说明" \
        less -R -- ${shortcutsHelpText}
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
      shortcutsHelp
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
      nixfmt
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
    withPython3 = false;
    withRuby = false;
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
    configType = "lua";
    extraConfig =
      lib.optionalString osConfig.virtualisation.vmware.guest.enable ''
        -- Keep the compositor on VMware SVGA3D, but make applications spawned
        -- by Hyprland use Mesa's software renderer for stability.
        hl.env("LIBGL_ALWAYS_SOFTWARE", "1")
      ''
      + builtins.readFile ./hyprland.lua;
  };

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    # 留空可让 Noctalia 设置界面管理配置。
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
