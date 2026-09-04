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

  hyprlandNested = pkgs.writeShellApplication {
    name = "hyprland-nested";
    runtimeInputs = [ pkgs.hyprland ];
    text = ''
      if [[ -z "''${WAYLAND_DISPLAY:-}" ]]; then
        echo "hyprland-nested requires a running WSLg Wayland session." >&2
        exit 1
      fi

      export HYPRLAND_NO_SD_TARGET=1
      export AQ_NO_KMS_REQUIREMENT=1
      exec Hyprland
    '';
  };
in
{
  imports = [ ./default.nix ];

  # Install explicit launchers for optional nested sessions. Neither compositor
  # is started automatically, so ordinary WSLg application windows still work.
  home.packages = [
    pkgs.niri
    niriNested
    hyprlandNested
  ];

  wayland.windowManager.hyprland = {
    enable = lib.mkForce true;
    package = lib.mkForce pkgs.hyprland;
    systemd.enable = lib.mkForce false;
  };

  programs.noctalia.enable = lib.mkForce false;
  programs.noctalia.systemd.enable = lib.mkForce false;
  services.hyprpolkitagent.enable = lib.mkForce false;

  # System activation runs without a graphical user bus in WSL. GTK derives
  # these values too, so force the merged dconf tree empty for this host.
  dconf.settings = lib.mkForce { };
}
