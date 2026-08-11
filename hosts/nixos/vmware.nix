{ lib, pkgs, username, ... }:
let
  kittySoftwareRendered = pkgs.symlinkJoin {
    name = "kitty-software-rendered";
    paths = [ pkgs.kitty ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/kitty --set LIBGL_ALWAYS_SOFTWARE 1
    '';
  };
in
{
  # Attach the VMware virtual disk to a SATA controller. The legacy LSI Logic
  # Parallel controller works in the LiveCD kernel but is unreliable with the
  # newer kernel used by this configuration.
  boot.initrd.availableKernelModules = [
    "ahci"
    "sd_mod"
  ];

  # These are physical AMD host settings inherited from hardware-configuration.nix.
  boot.initrd.kernelModules = lib.mkForce [
    "ahci"
    "sd_mod"
  ];
  boot.kernelModules = lib.mkForce [ ];
  hardware.cpu.amd.updateMicrocode = lib.mkForce false;

  virtualisation.vmware.guest.enable = true;

  home-manager.users.${username} = {
    # These can start outside Hyprland's child-process environment, so force
    # llvmpipe explicitly as well as setting the post-start desktop default.
    programs.kitty.package = kittySoftwareRendered;

    systemd.user.services.noctalia.Service.Environment = [
      "LIBGL_ALWAYS_SOFTWARE=1"
    ];
  };
}
