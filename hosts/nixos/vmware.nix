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
  # VMware's virtual LSI Logic Parallel controller needs this driver chain in
  # the initrd before the Btrfs root device can appear.
  boot.initrd.availableKernelModules = [
    "mptbase"
    "mptscsih"
    "mptspi"
    "scsi_transport_spi"
    "sd_mod"
  ];

  # These are physical AMD host settings inherited from hardware-configuration.nix.
  # Load mptspi explicitly: this VMware controller is not coldplugged reliably
  # by the installed initrd even though the module is available there.
  boot.initrd.kernelModules = lib.mkForce [
    "mptspi"
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
