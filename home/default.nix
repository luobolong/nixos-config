{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
let
  flclash = pkgs.callPackage ../packages/flclash.nix { };
  screenshot = pkgs.writeShellApplication {
    name = "hypr-screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      grimblast
      satty
      wl-clipboard
    ];
    text = ''
      target="''${1:-area}"
      freeze="''${2:-false}"
      directory="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
      mkdir -p "$directory"
      file="$directory/$(date +'%Y-%m-%d_%H-%M-%S-%N').png"
      raw_file="$(mktemp --suffix=.png)"
      trap 'rm -f "$raw_file"' EXIT

      args=()
      if [[ "$freeze" == "true" ]]; then
        args+=(--freeze)
      fi

      grimblast "''${args[@]}" save "$target" "$raw_file"
      satty --filename "$raw_file" --output-filename "$file"
    '';
  };
  commandPalette = pkgs.writeShellApplication {
    name = "hypr-command-palette";
    runtimeInputs = with pkgs; [
      brightnessctl
      fuzzel
      hyprland
      pipewire
    ];
    text = ''
      entries="$(${pkgs.coreutils}/bin/printf '%s\n' \
        $'close\tWindow  ·  SUPER + Q / ALT + F4  ·  Close the active window' \
        $'force-kill\tWindow  ·  SUPER + ALT + F4  ·  Force-kill the active window' \
        $'float\tWindow  ·  SUPER + W  ·  Toggle floating' \
        $'group\tWindow  ·  SUPER + G  ·  Toggle grouping' \
        $'pin\tWindow  ·  SUPER + SHIFT + W  ·  Toggle floating and pinning' \
        $'fullscreen\tWindow  ·  SUPER + D / SHIFT + F11  ·  Toggle fullscreen' \
        $'split\tWindow  ·  SUPER + J  ·  Toggle Dwindle split direction' \
        $'group-prev\tWindow  ·  SUPER + CTRL + H  ·  Previous window in group' \
        $'group-next\tWindow  ·  SUPER + CTRL + L  ·  Next window in group' \
        $'cycle\tWindow  ·  ALT + Tab  ·  Cycle window focus' \
        $'focus-left\tFocus  ·  SUPER + Left  ·  Focus left' \
        $'focus-right\tFocus  ·  SUPER + Right  ·  Focus right' \
        $'focus-up\tFocus  ·  SUPER + Up  ·  Focus up' \
        $'focus-down\tFocus  ·  SUPER + Down  ·  Focus down' \
        $'move-left\tWindow  ·  SUPER + CTRL + SHIFT + Left  ·  Move left' \
        $'move-right\tWindow  ·  SUPER + CTRL + SHIFT + Right  ·  Move right' \
        $'move-up\tWindow  ·  SUPER + CTRL + SHIFT + Up  ·  Move up' \
        $'move-down\tWindow  ·  SUPER + CTRL + SHIFT + Down  ·  Move down' \
        $'resize-left\tWindow  ·  SUPER + SHIFT + Left  ·  Shrink horizontally' \
        $'resize-right\tWindow  ·  SUPER + SHIFT + Right  ·  Grow horizontally' \
        $'resize-up\tWindow  ·  SUPER + SHIFT + Up  ·  Shrink vertically' \
        $'resize-down\tWindow  ·  SUPER + SHIFT + Down  ·  Grow vertically' \
        $'terminal\tApplication  ·  SUPER + T  ·  Open terminal' \
        $'dropdown\tApplication  ·  SUPER + ALT + T  ·  Toggle dropdown terminal' \
        $'files\tApplication  ·  SUPER + E  ·  Open file manager' \
        $'editor\tApplication  ·  SUPER + C  ·  Open VS Code' \
        $'browser\tApplication  ·  SUPER + B / F  ·  Open Firefox' \
        $'monitor\tApplication  ·  CTRL + SHIFT + Escape  ·  Open system monitor' \
        $'launcher\tApplication  ·  SUPER + A  ·  Open application launcher' \
        $'lock\tSystem  ·  SUPER + L  ·  Lock the screen' \
        $'workspace-empty\tWorkspace  ·  SUPER + CTRL + Down  ·  Switch to an empty workspace' \
        $'workspace-next-existing\tWorkspace  ·  SUPER + Wheel Down  ·  Next existing workspace' \
        $'workspace-prev-existing\tWorkspace  ·  SUPER + Wheel Up  ·  Previous existing workspace' \
        $'workspace-next\tWorkspace  ·  SUPER + CTRL + Right  ·  Next relative workspace' \
        $'workspace-prev\tWorkspace  ·  SUPER + CTRL + Left  ·  Previous relative workspace' \
        $'move-workspace-next\tWorkspace  ·  SUPER + ALT + CTRL + Right  ·  Move window to next workspace' \
        $'move-workspace-prev\tWorkspace  ·  SUPER + ALT + CTRL + Left  ·  Move window to previous workspace' \
        $'special-s\tWorkspace  ·  SUPER + S  ·  Toggle special workspace S' \
        $'special-m\tWorkspace  ·  SUPER + M  ·  Toggle special workspace M' \
        $'move-special-s\tWorkspace  ·  SUPER + SHIFT + S  ·  Move window to S and follow' \
        $'move-special-m\tWorkspace  ·  SUPER + SHIFT + M  ·  Move window to M and follow' \
        $'move-special-s-silent\tWorkspace  ·  SUPER + ALT + S  ·  Move window silently to S' \
        $'move-special-m-silent\tWorkspace  ·  SUPER + ALT + M  ·  Move window silently to M' \
        $'picker\tCapture  ·  SUPER + SHIFT + P  ·  Pick a color' \
        $'screenshot-area\tCapture  ·  SUPER + P  ·  Capture a screen region' \
        $'screenshot-freeze\tCapture  ·  SUPER + CTRL + P  ·  Freeze and capture a screen region' \
        $'screenshot-output\tCapture  ·  SUPER + ALT + P  ·  Capture the current display' \
        $'screenshot-screen\tCapture  ·  Print  ·  Capture all displays' \
        $'volume-up\tMedia  ·  Volume Up  ·  Raise volume by 5%' \
        $'volume-down\tMedia  ·  Volume Down  ·  Lower volume by 5%' \
        $'volume-mute\tMedia  ·  Mute  ·  Toggle mute' \
        $'brightness-up\tMedia  ·  Brightness Up  ·  Raise brightness by 5%' \
        $'brightness-down\tMedia  ·  Brightness Down  ·  Lower brightness by 5%' \
        $'workspace-1\tWorkspace  ·  SUPER + 1  ·  Switch to workspace 1' \
        $'workspace-2\tWorkspace  ·  SUPER + 2  ·  Switch to workspace 2' \
        $'workspace-3\tWorkspace  ·  SUPER + 3  ·  Switch to workspace 3' \
        $'workspace-4\tWorkspace  ·  SUPER + 4  ·  Switch to workspace 4' \
        $'workspace-5\tWorkspace  ·  SUPER + 5  ·  Switch to workspace 5' \
        $'workspace-6\tWorkspace  ·  SUPER + 6  ·  Switch to workspace 6' \
        $'workspace-7\tWorkspace  ·  SUPER + 7  ·  Switch to workspace 7' \
        $'workspace-8\tWorkspace  ·  SUPER + 8  ·  Switch to workspace 8' \
        $'workspace-9\tWorkspace  ·  SUPER + 9  ·  Switch to workspace 9' \
        $'workspace-10\tWorkspace  ·  SUPER + 0  ·  Switch to workspace 10' \
        $'move-workspace-1\tWorkspace  ·  SUPER + SHIFT + 1  ·  Move window to workspace 1' \
        $'move-workspace-2\tWorkspace  ·  SUPER + SHIFT + 2  ·  Move window to workspace 2' \
        $'move-workspace-3\tWorkspace  ·  SUPER + SHIFT + 3  ·  Move window to workspace 3' \
        $'move-workspace-4\tWorkspace  ·  SUPER + SHIFT + 4  ·  Move window to workspace 4' \
        $'move-workspace-5\tWorkspace  ·  SUPER + SHIFT + 5  ·  Move window to workspace 5' \
        $'move-workspace-6\tWorkspace  ·  SUPER + SHIFT + 6  ·  Move window to workspace 6' \
        $'move-workspace-7\tWorkspace  ·  SUPER + SHIFT + 7  ·  Move window to workspace 7' \
        $'move-workspace-8\tWorkspace  ·  SUPER + SHIFT + 8  ·  Move window to workspace 8' \
        $'move-workspace-9\tWorkspace  ·  SUPER + SHIFT + 9  ·  Move window to workspace 9' \
        $'move-workspace-10\tWorkspace  ·  SUPER + SHIFT + 0  ·  Move window to workspace 10'
      )"

      choice="$(
        ${pkgs.coreutils}/bin/printf '%s\n' "$entries" | fuzzel \
          --dmenu \
          --only-match \
          --no-sort \
          --with-nth=2 \
          --accept-nth=1 \
          --match-nth=2 \
          --prompt='⌕  ' \
          --placeholder='Search shortcuts, applications, or actions…' \
          --lines=16 \
          --width=72 \
          --font='Inter:size=12' \
          --counter \
          --border-radius=14 \
          --selection-radius=8 \
          --inner-pad=8 \
          --horizontal-pad=24 \
          --vertical-pad=10
      )" || exit 0

      dispatch() {
        hyprctl --quiet dispatch "$@"
      }

      case "$choice" in
        close) dispatch killactive ;;
        force-kill) dispatch forcekillactive ;;
        float) dispatch togglefloating ;;
        group) dispatch togglegroup ;;
        pin) dispatch setfloating; dispatch pin ;;
        fullscreen) dispatch fullscreen 0 ;;
        split) dispatch layoutmsg togglesplit ;;
        group-prev) dispatch changegroupactive b ;;
        group-next) dispatch changegroupactive f ;;
        cycle) dispatch cyclenext ;;
        focus-left) dispatch movefocus l ;;
        focus-right) dispatch movefocus r ;;
        focus-up) dispatch movefocus u ;;
        focus-down) dispatch movefocus d ;;
        move-left) dispatch movewindow l ;;
        move-right) dispatch movewindow r ;;
        move-up) dispatch movewindow u ;;
        move-down) dispatch movewindow d ;;
        resize-left) dispatch resizeactive -50 0 ;;
        resize-right) dispatch resizeactive 50 0 ;;
        resize-up) dispatch resizeactive 0 -50 ;;
        resize-down) dispatch resizeactive 0 50 ;;
        terminal) dispatch exec kitty ;;
        dropdown) dispatch togglespecialworkspace terminal ;;
        files) dispatch exec dolphin ;;
        editor) dispatch exec code ;;
        browser) dispatch exec firefox ;;
        monitor) dispatch exec missioncenter ;;
        launcher) dispatch exec fuzzel ;;
        lock) dispatch exec hyprlock ;;
        workspace-empty) dispatch workspace empty ;;
        workspace-next-existing) dispatch workspace 'e+1' ;;
        workspace-prev-existing) dispatch workspace 'e-1' ;;
        workspace-next) dispatch workspace 'r+1' ;;
        workspace-prev) dispatch workspace 'r-1' ;;
        move-workspace-next) dispatch movetoworkspace 'r+1' ;;
        move-workspace-prev) dispatch movetoworkspace 'r-1' ;;
        special-s) dispatch togglespecialworkspace S ;;
        special-m) dispatch togglespecialworkspace M ;;
        move-special-s) dispatch movetoworkspace special:S ;;
        move-special-m) dispatch movetoworkspace special:M ;;
        move-special-s-silent) dispatch movetoworkspacesilent special:S ;;
        move-special-m-silent) dispatch movetoworkspacesilent special:M ;;
        picker) dispatch exec 'hyprpicker -a' ;;
        screenshot-area) dispatch exec 'hypr-screenshot area' ;;
        screenshot-freeze) dispatch exec 'hypr-screenshot area true' ;;
        screenshot-output) dispatch exec 'hypr-screenshot output' ;;
        screenshot-screen) dispatch exec 'hypr-screenshot screen' ;;
        volume-up) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ ;;
        volume-down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
        volume-mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
        brightness-up) brightnessctl set 5%+ ;;
        brightness-down) brightnessctl set 5%- ;;
        workspace-*) dispatch workspace "''${choice#workspace-}" ;;
        move-workspace-*) dispatch movetoworkspace "''${choice#move-workspace-}" ;;
      esac
    '';
  };
in
{
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
    pointerCursor = {
      enable = true;
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 32;
      gtk.enable = true;
      x11.enable = true;
    };
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
      commandPalette
      brightnessctl
      playerctl
      networkmanagerapplet
      nwg-displays
      xlsclients

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
      codex
    ];
    preferXdgDirectories = true;
  };

  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "luobolong";
        email = "benjcarrot@gmail.com";
        signingKey = "223526AB6B297BE2";
      };
      commit.gpgSign = true;
    };
  };
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
  gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus";
      package = pkgs.papirus-icon-theme;
    };
  };
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
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
    # Noctalia writes this file whenever its active palette changes.
    extraConfig = ''
      include themes/noctalia.conf
    '';
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

  xdg.configFile."kdeglobals".text = ''
    [Icons]
    Theme=Papirus
  '';

  xdg.configFile."fuzzel/fuzzel.ini".text = ''
    [main]
    include=${inputs.catppuccin-fuzzel}/themes/catppuccin-mocha/mauve.ini
    font=Inter:size=12
    icon-theme=Papirus
    terminal=kitty
  '';

  xdg.configFile."satty/config.toml".text = ''
    [general]
    annotation-size-factor = 1
    copy-command = "wl-copy"

    [font]
    family = "Noto Sans CJK SC"
    style = "Regular"

    fallback = [
        "Noto Sans",
        "Noto Color Emoji",
    ]

    [color-palette]
    palette = [
        "#ff0000ff",
        "#ffaa00ff",
        "#ffff00ff",
        "#00cc66ff",
        "#0088ffff",
        "#ffffffFF",
        "#000000FF",
    ]
  '';

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
    extraConfig = builtins.readFile ./hyprland.lua;
  };

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    # These are defaults; Noctalia's settings UI can still override them at runtime.
    settings.theme.templates = {
      enable_builtin_templates = true;
      builtin_ids = [
        "alacritty"
        "btop"
        "cava"
        "emacs"
        "foot"
        "ghostty"
        "gtk3"
        "gtk4"
        "helix"
        "kcolorscheme"
        "kitty"
        "labwc"
        "niri"
        "hyprland"
        "mango"
        "qt"
        "scroll"
        "sway"
        "starship"
        "wezterm"
      ];
    };
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
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "32";
  };
}
