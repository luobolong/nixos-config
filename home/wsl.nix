{ lib, pkgs, ... }:
let
  niriNested = pkgs.writeShellApplication {
    name = "niri-nested";
    runtimeInputs = [ pkgs.niri ];
    text = ''
      if [[ -z "''${WAYLAND_DISPLAY:-}" ]]; then
        echo "niri-nested requires a running WSLg Wayland session." >&2
        exit 1
      fi

      exec niri
    '';
  };

in
{
  imports = [ ./default.nix ];

  # Niri is started explicitly as a nested session, so ordinary WSLg
  # application windows continue to work when it is not running.
  home.packages = [
    pkgs.niri
    niriNested
  ];

  wayland.windowManager.hyprland.enable = lib.mkForce false;

  # Install Noctalia and generate its configuration, but let Niri start it with
  # the nested Wayland display in its environment.
  programs.noctalia.enable = lib.mkForce true;
  programs.noctalia.systemd.enable = lib.mkForce false;
  services.hyprpolkitagent.enable = lib.mkForce false;

  # System activation runs without a graphical user bus in WSL. GTK derives
  # these values too, so force the merged dconf tree empty for this host.
  dconf.settings = lib.mkForce { };
}
