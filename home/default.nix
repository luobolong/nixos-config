{ config, inputs, lib, pkgs, username, ... }:
let
  flclash = pkgs.callPackage ../packages/flclash.nix { };
in
{
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
    packages = with pkgs; [
      vscode
      spotify
      flclash
      kitty
      nautilus
      firefox
      wl-clipboard
      grim
      slurp
      brightnessctl
      playerctl
      pavucontrol
      networkmanagerapplet
      unzip
      ripgrep
      fd
      gcc
      gnumake
      nodejs
      python3
      lua-language-server
      nil
      nixfmt-rfc-style
    ];
  };

  programs.home-manager.enable = true;
  programs.git.enable = true;
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    extraPackages = with pkgs; [ tree-sitter ];
  };

  xdg.enable = true;
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

  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    systemd.enable = true;
    settings = {
      "$mod" = "SUPER";
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
        blur.enabled = true;
      };
      animations.enabled = true;
      exec-once = [
        "fcitx5 -d --replace"
        "nm-applet --indicator"
      ];
      bind = [
        "$mod, Return, exec, kitty"
        "$mod, E, exec, nautilus"
        "$mod, B, exec, firefox"
        "$mod, Q, killactive"
        "$mod SHIFT, M, exit"
        "$mod, F, fullscreen"
        "$mod, V, togglefloating"
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
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

  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    XMODIFIERS = "@im=fcitx";
  };
}
