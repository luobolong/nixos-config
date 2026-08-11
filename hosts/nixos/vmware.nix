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
  # The systemd-based initrd in the current unstable snapshot sees the VMware
  # SATA partitions in /dev, but leaves their .device units inactive.  The
  # scripted stage-1 waits for the device path directly and avoids that udev /
  # systemd device-unit failure.
  boot.initrd.systemd.enable = lib.mkForce false;

  # Attach the VMware virtual disk to a SATA controller. The legacy LSI Logic
  # Parallel controller works in the LiveCD kernel but is unreliable with the
  # newer kernel used by this configuration.
  boot.initrd.availableKernelModules = [
    "ahci"
    "sd_mod"
    "btrfs"
  ];

  # Replace the physical AMD early-module list while retaining every module
  # required to discover and mount the VMware Btrfs root filesystem.
  boot.initrd.kernelModules = lib.mkForce [
    "ahci"
    "sd_mod"
    "btrfs"
  ];
  boot.initrd.supportedFilesystems = [ "btrfs" ];
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
