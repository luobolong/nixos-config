{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
let
  chatgpt = pkgs.callPackage ../packages/chatgpt.nix { };
  deepseekHarness = pkgs.callPackage ../packages/deepseek-harness.nix { };
  codexUpdater = pkgs.writeShellApplication {
    name = "codex-update";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      findutils
      gawk
      gnugrep
      gnused
      gnutar
      util-linux
    ];
    text = ''
      export CODEX_INSTALL_DIR="$HOME/.local/bin"
      export CODEX_NON_INTERACTIVE=1
      export PATH="$CODEX_INSTALL_DIR:$PATH"

      curl -fsSL https://chatgpt.com/codex/install.sh | ${pkgs.runtimeShell}
    '';
  };
  claudeCode =
    (import inputs.nixpkgs-claude {
      system = pkgs.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    }).claude-code;
  audiomonitor =
    inputs.audiomonitor.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
      (oldAttrs: {
        postInstall =
          builtins.replaceStrings
            [
              ''bash "$packageSource/packaging/create-icon.sh" $out/share/icons/hicolor/256x256/apps''
            ]
            [
              ''
                install -Dm644 "$packageSource/resources/icons/appicon_256.png" \
                              $out/share/icons/hicolor/256x256/apps/audiomonitor.png''
            ]
            oldAttrs.postInstall;
      });
  catppuccinKde = pkgs.catppuccin-kde.override {
    flavour = [ "mocha" ];
    accents = [ "mauve" ];
    winDecStyles = [ "modern" ];
  };
  catppuccinKvantum = pkgs.catppuccin-kvantum.override {
    variant = "mocha";
    accent = "mauve";
  };
  dolphinUiStyle = pkgs.writeText "dolphin-ui.qss" ''
    QWidget {
      font-size: 9pt;
    }

    QDockWidget#placesDock {
      min-height: 350px;
    }
  '';
  rimeDefaultCustom = pkgs.writeText "rime-default-custom.yaml" ''
    patch:
      menu/page_size: 7
  '';
  dolphin = pkgs.symlinkJoin {
    name = "dolphin-kvantum";
    paths = [ pkgs.kdePackages.dolphin ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/dolphin" \
        --set QT_QPA_PLATFORMTHEME qt6ct \
        --set QT_STYLE_OVERRIDE kvantum \
        --add-flags "-stylesheet ${dolphinUiStyle}" \
        --prefix QT_PLUGIN_PATH : "${
          lib.makeSearchPath "lib/qt-6/plugins" [
            pkgs.kdePackages.qt6ct
            pkgs.kdePackages.qtstyleplugin-kvantum
          ]
        }"
    '';
  };
  spotify = pkgs.symlinkJoin {
    name = "spotify-wayland";
    paths = [ pkgs.spotify ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/spotify" \
        --set NIXOS_OZONE_WL 1 \
        --add-flags "--enable-features=UseOzonePlatform" \
        --add-flags "--ozone-platform=wayland" \
        --add-flags "--enable-wayland-ime" \
        --add-flags "--wayland-text-input-version=3"
    '';
  };
  qqWayland = pkgs.qq.override {
    commandLineArgs = lib.concatStringsSep " " [
      "--ozone-platform=wayland"
      "--enable-wayland-ime"
      "--wayland-text-input-version=3"
    ];
  };
  linuxqqClipsync = pkgs.rustPlatform.buildRustPackage {
    pname = "linuxqq-clipsync";
    version = "0.1.0";
    src = inputs.linuxqq-clipsync;
    cargoLock.lockFile = "${inputs.linuxqq-clipsync}/Cargo.lock";
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postInstall = ''
      wrapProgram "$out/bin/linuxqq-clipsync" \
        --prefix PATH : "${
          lib.makeBinPath [
            pkgs.clipnotify
            pkgs.wl-clipboard
            pkgs.xclip
          ]
        }"
    '';
    meta = {
      description = "Synchronize the X11 and Wayland clipboards for Linux QQ";
      homepage = "https://github.com/SHORiN-KiWATA/linuxqq-clipsync";
      license = lib.licenses.mit;
      mainProgram = "linuxqq-clipsync";
    };
  };
  screenshot = pkgs.writeShellApplication {
    name = "hypr-screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      grim
      grimblast
      jq
      niri
      satty
      slurp
      wayfreeze
      wl-clipboard
    ];
    text = ''
      target="''${1:-area}"
      freeze="''${2:-false}"
      directory="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
      mkdir -p "$directory"
      file="$directory/$(date +'%Y-%m-%d_%H-%M-%S-%N').png"
      raw_file="$(mktemp --suffix=.png)"
      freeze_pid=""

      cleanup() {
        if [[ -n "$freeze_pid" ]]; then
          kill "$freeze_pid" 2>/dev/null || true
          wait "$freeze_pid" 2>/dev/null || true
        fi
        rm -f "$raw_file"
      }
      trap cleanup EXIT

      unfreeze() {
        if [[ -n "$freeze_pid" ]]; then
          kill "$freeze_pid" 2>/dev/null || true
          wait "$freeze_pid" 2>/dev/null || true
          freeze_pid=""
        fi
      }

      if [[ -n "''${NIRI_SOCKET:-}" ]]; then
        case "$target" in
          area)
            if [[ "$freeze" == "true" ]]; then
              wayfreeze --hide-cursor &
              freeze_pid=$!
              sleep 0.1
            fi

            geometry="$(slurp)" || exit 0
            grim -g "$geometry" "$raw_file"
            ;;
          output)
            output="$(niri msg --json focused-output | jq -er '.name')"
            grim -o "$output" "$raw_file"
            ;;
          screen)
            grim "$raw_file"
            ;;
          *)
            echo "unsupported screenshot target for niri: $target" >&2
            exit 2
            ;;
        esac
      else
        args=()
        if [[ "$freeze" == "true" ]]; then
          args+=(--freeze)
        fi

        grimblast "''${args[@]}" save "$target" "$raw_file"
      fi

      unfreeze
      satty --filename "$raw_file" --output-filename "$file"
    '';
  };
  niriSmartDirection = pkgs.writeShellApplication {
    name = "niri-smart-direction";
    runtimeInputs = with pkgs; [
      jq
      niri
    ];
    text = builtins.readFile ./niri-smart-direction.sh;
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
        $'maximize\tWindow  ·  SUPER + M  ·  Toggle maximized' \
        $'split\tWindow  ·  SUPER + J  ·  Toggle Dwindle split direction' \
        $'group-prev\tWindow  ·  SUPER + CTRL + H  ·  Previous window in group' \
        $'group-next\tWindow  ·  SUPER + CTRL + L  ·  Next window in group' \
        $'window-overview\tWindow  ·  ALT + Tab  ·  Open Noctalia window overview' \
        $'zoom-toggle\tAccessibility  ·  SUPER + ALT + Z  ·  Toggle 2x screen magnification' \
        $'zoom-adjust\tAccessibility  ·  SUPER + ALT + Wheel  ·  Adjust screen magnification' \
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
        $'files\tApplication  ·  SUPER + E  ·  Open file manager' \
        $'editor\tApplication  ·  SUPER + C  ·  Open VS Code' \
        $'browser\tApplication  ·  SUPER + B / F  ·  Open Firefox' \
        $'monitor\tApplication  ·  CTRL + SHIFT + Escape  ·  Open system monitor' \
        $'launcher\tApplication  ·  SUPER + A  ·  Open application launcher' \
        $'clipboard\tApplication  ·  SUPER + V  ·  Open Noctalia clipboard' \
        $'lock\tSystem  ·  SUPER + L  ·  Lock the screen' \
        $'workspace-empty\tWorkspace  ·  SUPER + CTRL + Down  ·  Switch to an empty workspace' \
        $'workspace-next-existing\tWorkspace  ·  SUPER + Wheel Down  ·  Next existing workspace' \
        $'workspace-prev-existing\tWorkspace  ·  SUPER + Wheel Up  ·  Previous existing workspace' \
        $'workspace-next\tWorkspace  ·  SUPER + CTRL + Right  ·  Next relative workspace' \
        $'workspace-prev\tWorkspace  ·  SUPER + CTRL + Left  ·  Previous relative workspace' \
        $'move-workspace-next\tWorkspace  ·  SUPER + ALT + CTRL + Right  ·  Move window to next workspace' \
        $'move-workspace-prev\tWorkspace  ·  SUPER + ALT + CTRL + Left  ·  Move window to previous workspace' \
        $'special-s\tWorkspace  ·  SUPER + S  ·  Toggle special workspace S' \
        $'move-special-s\tWorkspace  ·  SUPER + SHIFT + S  ·  Move window to S and follow' \
        $'move-special-s-silent\tWorkspace  ·  SUPER + ALT + S  ·  Move window silently to S' \
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
        maximize) dispatch fullscreen 1 ;;
        split) dispatch layoutmsg togglesplit ;;
        group-prev) dispatch changegroupactive b ;;
        group-next) dispatch changegroupactive f ;;
        window-overview) noctalia msg window-switcher ;;
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
        files) dispatch exec dolphin ;;
        editor) dispatch exec code ;;
        browser) dispatch exec firefox ;;
        monitor) dispatch exec missioncenter ;;
        launcher) noctalia msg panel-toggle launcher ;;
        clipboard) noctalia msg panel-toggle clipboard ;;
        lock) dispatch exec hyprlock ;;
        workspace-empty) dispatch workspace empty ;;
        workspace-next-existing) dispatch workspace 'e+1' ;;
        workspace-prev-existing) dispatch workspace 'e-1' ;;
        workspace-next) dispatch workspace 'r+1' ;;
        workspace-prev) dispatch workspace 'r-1' ;;
        move-workspace-next) dispatch movetoworkspace 'r+1' ;;
        move-workspace-prev) dispatch movetoworkspace 'r-1' ;;
        special-s) dispatch togglespecialworkspace S ;;
        move-special-s) dispatch movetoworkspace special:S ;;
        move-special-s-silent) dispatch movetoworkspacesilent special:S ;;
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
  imports = [ ./zsh.nix ];

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
      # Desktop applications
      vscode
      jetbrains.idea
      jetbrains.datagrip
      jetbrains.goland
      spotify
      qqWayland
      linuxqqClipsync
      discord
      telegram-desktop
      cc-switch
      dolphin
      kdePackages.okular
      kdePackages.gwenview
      kdePackages.ark
      kdePackages.baloo-widgets
      kdePackages.ffmpegthumbs
      kdePackages.kio-extras
      catppuccinKde
      firefox
      localsend
      mission-center
      obs-studio
      pavucontrol
      audiomonitor

      # Hyprland and Wayland desktop tools
      fuzzel
      wl-clipboard
      hyprpicker
      grimblast
      grim
      slurp
      screenshot
      commandPalette
      niriSmartDirection
      brightnessctl
      playerctl
      mpv
      mpvpaper
      networkmanagerapplet
      nwg-displays
      xwayland-satellite
      xlsclients

      # Terminal and file search tools
      fastfetch
      btop
      ripgrep
      fd
      file
      tree
      which
      lsof

      # Data processing, transfer, and archive tools
      jq
      yq-go
      rsync
      zip
      unzip
      p7zip

      # Hardware, storage, and network diagnostics
      pciutils
      usbutils
      smartmontools
      nvme-cli
      lm_sensors
      dnsutils

      # Routine NixOS maintenance tools
      nh
      nix-output-monitor
      nvd

      # Development, build, and language tools
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
      # Keep nixpkgs' Codex as an offline fallback until the standalone updater
      # has installed the latest release into ~/.local/bin.
      codex
      codexUpdater
      chatgpt
      claudeCode
      deepseekHarness
      sops
    ];
    preferXdgDirectories = true;
  };

  programs.home-manager.enable = true;
  programs.java = {
    enable = true;
    # OpenJDK includes lib/src.zip for IDE source navigation.
    package = pkgs.openjdk25;
  };
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
  gtk = {
    enable = true;
    colorScheme = "dark";
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
    kvantum = {
      enable = true;
      themes = [ catppuccinKvantum ];
      settings.General.theme = "catppuccin-mocha-mauve";
    };
    qt5ctSettings.Appearance = {
      color_scheme_path = "${catppuccinKde}/share/color-schemes/CatppuccinMochaMauve.colors";
      custom_palette = true;
      icon_theme = "Papirus-Dark";
      standard_dialogs = "default";
      style = "kvantum";
    };
    qt6ctSettings.Appearance = {
      color_scheme_path = "${catppuccinKde}/share/color-schemes/CatppuccinMochaMauve.colors";
      custom_palette = true;
      icon_theme = "Papirus-Dark";
      standard_dialogs = "default";
      style = "kvantum";
    };
  };
  programs.kitty = {
    enable = true;
    themeFile = "Catppuccin-Mocha";
    settings = {
      font_family = "JetBrainsMono Nerd Font";
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";
      font_size = 11;
      window_padding_width = 15;
      enable_audio_bell = "no";
      cursor_trail = 1;
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
        niri = [ "kitty.desktop" ];
        default = [ "kitty.desktop" ];
      };
    };
    mimeApps = {
      enable = true;
      defaultApplications = {
        "inode/directory" = [ "org.kde.dolphin.desktop" ];
        "application/pdf" = [ "okularApplication_pdf.desktop" ];
        "application/epub+zip" = [ "okularApplication_epub.desktop" ];
        "image/jpeg" = [ "org.kde.gwenview.desktop" ];
        "image/png" = [ "org.kde.gwenview.desktop" ];
        "image/gif" = [ "org.kde.gwenview.desktop" ];
        "image/webp" = [ "org.kde.gwenview.desktop" ];
        "image/svg+xml" = [ "org.kde.gwenview.desktop" ];
        "text/plain" = [ "code.desktop" ];
        "audio/mpeg" = [ "mpv.desktop" ];
        "audio/flac" = [ "mpv.desktop" ];
        "audio/ogg" = [ "mpv.desktop" ];
        "audio/x-wav" = [ "mpv.desktop" ];
        "video/mp4" = [ "mpv.desktop" ];
        "video/x-matroska" = [ "mpv.desktop" ];
        "video/webm" = [ "mpv.desktop" ];
        "application/zip" = [ "org.kde.ark.desktop" ];
        "application/x-7z-compressed" = [ "org.kde.ark.desktop" ];
        "application/vnd.rar" = [ "org.kde.ark.desktop" ];
        "application/x-tar" = [ "org.kde.ark.desktop" ];
        "text/html" = [ "firefox.desktop" ];
        "application/xhtml+xml" = [ "firefox.desktop" ];
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
      };
    };
    userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = true;
      projects = "${config.home.homeDirectory}/Workspace";
    };
  };

  # Keep the network and Bluetooth services available without starting their
  # legacy tray applets automatically; Noctalia provides the desktop controls.
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=NetworkManager Applet
    Hidden=true
  '';
  xdg.configFile."autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Blueman Applet
    Hidden=true
  '';

  xdg.configFile."nvim" = {
    source = inputs.astronvim;
    recursive = true;
  };
  xdg.configFile."nvim/lua/plugins/absolute-line-numbers.lua".text = ''
    return {
      "AstroNvim/astrocore",
      opts = {
        options = {
          opt = {
            number = true,
            relativenumber = false,
          },
        },
      },
    }
  '';

  xdg.configFile."kdeglobals".text = ''
    [Colors:View]
    BackgroundNormal=#00000000

    [General]
    ColorScheme=CatppuccinMochaMauve
    TerminalApplication=kitty

    [Icons]
    Theme=Papirus-Dark

    [UiSettings]
    ColorScheme=CatppuccinMochaMauve

    [Wallet]
    Enabled=false
  '';

  # Mirror HyDE's compact, transparent Dolphin layout.
  xdg.configFile."dolphinrc".text = ''
    MenuBar=Disabled

    [General]
    ShowSelectionToggle=false
    ShowStatusBar=false

    [IconsMode]
    MaximumTextLines=1
    PreviewSize=112

    [InformationPanel]
    dateFormat=ShortFormat

    [KFileDialog Settings]
    Places Icons Auto-resize=false
    Places Icons Static Size=16

    [MainWindow]
    MenuBar=Disabled
    ToolBarsMovable=Disabled

    [MainWindow][Toolbar mainToolBar]
    IconSize=16
    ToolButtonStyle=IconOnly

    [PlacesPanel]
    IconSize=16

    [Toolbar mainToolBar]
    ToolButtonStyle=IconOnly
  '';

  # Dolphin stores dock placement and visibility separately from dolphinrc.
  # Keep the Places and Information panels on the right, with the unavailable
  # Konsole terminal panel hidden.
  xdg.stateFile."dolphinstaterc" = {
    force = true;
    text = ''
      [State]
      State=AAAA/wAAAAD9AAAAAwAAAAAAAACTAAAD4PwCAAAAAfsAAAAWAGYAbwBsAGQAZQByAHMARABvAGMAawAAAAAA/////wAAAAAA////AAAAAQAAALUAAAJy/AIAAAAC+wAAABQAcABsAGEAYwBlAHMARABvAGMAawEAAAAAAAAA+gAAAEEA////+wAAABAAaQBuAGYAbwBEAG8AYwBrAQAAAQEAAAFxAAAA1wD///8AAAADAAAFXgAAATv8AQAAAAH7AAAAGAB0AGUAcgBtAGkAbgBhAGwARABvAGMAawAAAAAAAAAFXgAAAI0A////AAAEogAAAnIAAAAEAAAABAAAAAgAAAAI/AAAAAEAAAABAAAAAQAAABYAbQBhAGkAbgBUAG8AbwBsAEIAYQByAwAAAAD/////AAAAAAAAAAA=
    '';
  };

  xdg.configFile."fuzzel/fuzzel.ini".text = ''
    [main]
    include=${inputs.catppuccin-fuzzel}/themes/catppuccin-mocha/mauve.ini
    font=Inter:size=12
    icon-theme=Papirus-Dark
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

  # rime-ice writes compiled artifacts into the user directory, so deploy it
  # as a writable copy.
  home.activation.installRimeIce = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ${config.home.homeDirectory}/.local/share/fcitx5/rime
    $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -rL --chmod=u+w ${inputs.rime-ice}/ ${config.home.homeDirectory}/.local/share/fcitx5/rime/
    $DRY_RUN_CMD install -m 0644 ${rimeDefaultCustom} ${config.home.homeDirectory}/.local/share/fcitx5/rime/default.custom.yaml
  '';

  # Codex releases faster than nixpkgs. Refresh the standalone installation
  # whenever Home Manager applies a new generation.
  home.activation.updateCodex = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! $DRY_RUN_CMD ${lib.getExe codexUpdater}; then
      echo "warning: unable to update Codex CLI; keeping the installed fallback" >&2
    fi
  '';

  # Keep niri's runtime-generated includes writable and available on first login.
  # The noctalia.kdl file also signals to Noctalia that config.kdl already includes it.
  home.activation.ensureNiriRuntimeIncludes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ${config.xdg.configHome}/niri
    if [[ ! -f ${config.xdg.configHome}/niri/noctalia.kdl ]]; then
      $DRY_RUN_CMD touch ${config.xdg.configHome}/niri/noctalia.kdl
    fi
    if [[ ! -f ${config.xdg.configHome}/niri/monitor.kdl ]]; then
      $DRY_RUN_CMD touch ${config.xdg.configHome}/niri/monitor.kdl
    fi
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
    # Horizontal candidate list
    Vertical Candidate List=False

    # Scale according to each display's DPI
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

  # This file is fully managed here. Replace an existing copy directly so a
  # stale .hm-backup from an earlier activation cannot block future rebuilds.
  xdg.configFile."niri/config.kdl" = {
    source = ./niri.kdl;
    force = true;
  };

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    # Keep the bar transparent while giving capsules a subtle fill; their
    # outline and hover feedback remain visible.
    settings.bar = {
      order = [ "default" ];
      default = {
        background_opacity = 0.0;
        border_width = 0.0;
        capsule = true;
        capsule_border = "outline";
        capsule_foreground = "#FFFFFF";
        capsule_opacity = 0.3;
        capsule_padding = 10.0;
        capsule_radius = 80;
        capsule_thickness = 1.0;
        color = "#FFFFFF";
        enabled = true;
        hover_highlight = true;
        panel_overlap = 12;
        font_family = "JetBrainsMono Nerd Font";
        margin_ends = 14;
        margin_edge = 5;
        scale = 1.1;
        shadow = false;
        start = [
          "launcher"
          "settings"
          "workspaces"
          "active_window"
        ];
        center = [ "clock" ];
        end = [
          "tray"
          "wallpaper"
          "network"
          "bluetooth"
          "volume"
          "battery"
          "notifications"
          "session"
        ];
        thickness = 26;
      };
    };
    settings.plugins.enabled = [ "noctalia/mpvpaper" ];
    settings.widget.mpvpaper.type = "noctalia/mpvpaper:mpvpaper";
    # Keep Kitty, Starship, and KDE/Qt out of dynamic templates so their fixed
    # configurations are not overwritten on palette changes.
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
        "labwc"
        "niri"
        "hyprland"
        "mango"
        "scroll"
        "sway"
        "wezterm"
      ];
    };
  };

  # Dolphin delegates removable and secondary-drive mounts to UDisks2, which
  # needs a PolicyKit authentication agent in the graphical user session.
  services.hyprpolkitagent.enable = true;
  services.mako.enable = false;
  services.gpg-agent = {
    enable = true;
    enableZshIntegration = true;
    pinentry.package = pkgs.pinentry-qt;
  };
  services.ssh-agent.enable = true;

  systemd.user.services.linuxqq-clipsync = {
    Unit = {
      Description = "Synchronize X11 and Wayland clipboards for Linux QQ";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.getExe linuxqqClipsync;
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.sessionPath = [ "$HOME/.local/bin" ];
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    TERMINAL = "kitty";
    XMODIFIERS = "@im=fcitx";
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "32";
  };
}
