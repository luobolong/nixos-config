{ lib, ... }:
{
  imports = [ ./default.nix ];

  # WSLg already provides the compositor and login/session boundary. Keep the
  # application configuration available, but do not start a nested desktop.
  wayland.windowManager.hyprland.enable = lib.mkForce false;
  programs.noctalia.enable = lib.mkForce false;
  programs.noctalia.systemd.enable = lib.mkForce false;
  services.hyprpolkitagent.enable = lib.mkForce false;
}
