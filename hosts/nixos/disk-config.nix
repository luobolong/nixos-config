{ lib, ... }:
{
  # The VMware installation uses a single virtual SATA disk. Keep this layout
  # in sync with the installed disk: ESP on partition 1 and Btrfs on partition
  # 2. In particular, do not declare a swap partition that does not exist,
  # because resume support would make the initrd wait for it indefinitely.
  disko.devices.disk.main = {
    type = "disk";
    device = lib.mkDefault "/dev/sda";
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
