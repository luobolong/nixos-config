{ lib, ... }:
{
  # Replace this with the actual disk's /dev/disk/by-id/... path before
  # installation.
  disko.devices.disk.main = {
    type = "disk";
    device = lib.mkDefault "/dev/disk/by-id/CHANGE_ME";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          name = "ESP";
          start = "1M";
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        swap = {
          # Match this host's 64 GiB of RAM to reserve enough space for the
          # hibernation image.
          size = "64G";
          content = {
            type = "swap";
            # Disko configures this partition as boot.resumeDevice.
            # Hibernation cannot use randomEncryption because its key changes
            # on every boot.
            resumeDevice = true;
          };
        };

        system = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" "-L" "nixos" ];
            subvolumes = {
              "@root" = {
                mountpoint = "/";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              "@root/.snapshots" = { };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              "@home/.snapshots" = { };
            };
          };
        };
      };
    };
  };
}
