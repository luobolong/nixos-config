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
          # 与本机 64 GiB 内存等大，为休眠镜像预留足够空间。
          size = "64G";
          content = {
            type = "swap";
            # 由 Disko 将此分区配置为 boot.resumeDevice。
            # 休眠不能使用每次开机更换密钥的 randomEncryption。
            resumeDevice = true;
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
              # 与 /persist 同级，挂载到其内部供 Snapper 保存快照，
              # 避免快照递归包含其他快照。
              "/persist-snapshots" = {
                mountpoint = "/persist/.snapshots";
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
