{
  # Single-disk Windows + NixOS layout. Windows owns the existing GPT, ESP and
  # recovery partitions; NixOS only mounts three partitions created in the free
  # space: NIXBOOT, nixos-swap and nixos. Labels keep this independent of
  # partition numbers, which vary depending on the Windows installation.
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@root"
        "compress=zstd"
        "noatime"
      ];
    };

    "/nix" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@nix"
        "compress=zstd"
        "noatime"
      ];
    };

    "/home" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@home"
        "compress=zstd"
        "noatime"
      ];
    };

    # Keep a dedicated 2 GiB ESP for NixOS UKIs. The Windows ESP is usually too
    # small for several Lanzaboote generations, even on a single physical disk.
    "/boot" = {
      device = "/dev/disk/by-label/NIXBOOT";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };
  };

  # Mount the dedicated 32 GiB swap partition. The initrd automatically tries
  # non-randomly-encrypted swap devices for resume.
  swapDevices = [ { device = "/dev/disk/by-label/nixos-swap"; } ];
}
