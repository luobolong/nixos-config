{
  # Single-disk Windows + NixOS layout. Windows owns the existing GPT, ESP and
  # recovery partitions; NixOS only mounts two partitions created in the free
  # space: NIXBOOT and nixos. Labels keep this independent of
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
}
