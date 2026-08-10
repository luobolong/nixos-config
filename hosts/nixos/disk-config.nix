{ lib, ... }:
{
  # 安装前必须把这里改成实际磁盘的 /dev/disk/by-id/... 路径。
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
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        swap = {
          size = "16G";
          content = {
            type = "swap";
            randomEncryption = true;
          };
        };

        system = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" "-L" "nixos" ];
            subvolumes = {
              "/nix" = {
                mountpoint = "/nix";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              "/persist" = {
                mountpoint = "/persist";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
            };
          };
        };
      };
    };
  };

  # 临时根目录：重启即清空；需要保留的内容由 impermanence 绑定到 /persist。
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "defaults" "mode=755" "size=8G" ];
  };
  fileSystems."/persist".neededForBoot = true;
}
