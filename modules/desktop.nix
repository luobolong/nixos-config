{ config, pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };
  # Install Hyprlock and its PAM service directly. The programs.hyprlock module
  # also enables Hypridle automatically, which is intentionally not wanted.
  environment.systemPackages = [ pkgs.hyprlock ];
  security.pam.services.hyprlock = { };

  programs.niri = {
    enable = true;
  };

  programs.noctalia = {
    enable = true;
    recommendedServices.enable = true;
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions /run/current-system/sw/share/wayland-sessions";
      user = "greeter";
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;
  security.polkit.enable = true;
  services.udisks2.enable = true;

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-rime
        fcitx5-gtk
        qt6Packages.fcitx5-configtool
        catppuccin-fcitx5
      ];
    };
  };

  # Niri/Hyprland sessions do not consistently launch XDG autostart entries.
  # Start Fcitx explicitly as a user service after the graphical session exists.
  systemd.user.services.fcitx5 = {
    description = "Fcitx 5 input method";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${config.i18n.inputMethod.package}/bin/fcitx5";
      Restart = "on-failure";
      RestartSec = "2s";
    };
    wantedBy = [ "graphical-session.target" ];
  };

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      inter
      source-serif
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      noto-fonts-monochrome-emoji
      sarasa-gothic
      nerd-fonts.cousine
      nerd-fonts.jetbrains-mono
    ];
    fontconfig = {
      localConf = builtins.readFile ./fonts.conf;
      defaultFonts = {
        sansSerif = [ ];
        serif = [ ];
        monospace = [ ];
        emoji = [ ];
      };
    };
  };
}
