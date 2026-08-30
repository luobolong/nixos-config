{ pkgs, ... }:
let
  # niri-session still calls import-environment without variable names, which
  # systemd has deprecated. Preserve its import-all behavior while avoiding the
  # warning until https://github.com/niri-wm/niri/issues/254 is fixed upstream.
  niriPackage = pkgs.symlinkJoin {
    name = "niri-${pkgs.niri.version}-session-env-fix";
    paths = [ pkgs.niri ];
    passthru.providedSessions = pkgs.niri.providedSessions;
    meta = pkgs.niri.meta;
    postBuild = ''
      rm "$out/bin/niri-session"
      substitute ${pkgs.niri}/bin/niri-session "$out/bin/niri-session" \
        --replace-fail \
          'systemctl --user import-environment' \
          'systemctl --user import-environment $(printenv | cut -d= -f1 | tr "\n" " ")'
      chmod +x "$out/bin/niri-session"
    '';
  };
in
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
    package = niriPackage;
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
