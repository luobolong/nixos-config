{ config, lib, pkgs, ... }:
let
  # 与 home/default.nix 中相同的 callPackage 参数 → 同一个 store path,
  # 不会重复构建,也不需要改动 home-manager 侧。
  flclash = pkgs.callPackage ../packages/flclash.nix { };
in
{
  # TUN 模式需要内核 tun 模块(本机为 CONFIG_TUN=m,默认未加载)
  boot.kernelModules = [ "tun" ];

  # FlClash 的 AppImage 包装(bubblewrap)以普通用户、零 capabilities 运行,
  # 创建 TUN 网卡(TUNSETIFF)需要 CAP_NET_ADMIN,所以 TUN 模式必然失败。
  # 这里用 security.wrappers 生成一个带文件能力 cap_net_admin 的 ELF 包装,
  # 放到 /run/wrappers/bin/flclash(PATH 中优先于用户 profile):
  #   执行时把能力提升为 ambient 再 exec 原始脚本,整个进程树
  #   (GUI → FlClashCore)以普通用户身份继承 CAP_NET_ADMIN。
  # 做法与 nixpkgs 的 programs.clash-verge.tunMode 一致。
  security.wrappers.flclash = {
    owner = "root";
    group = "root";
    capabilities = "cap_net_admin=+ep";
    source = "${flclash}/bin/flclash";
  };

  # 备用:若 TUN 网卡能创建但流量仍不通,可启用 rp_filter loose
  # (内核取 all 与接口两者更严格者,wlp1s0 当前为 strict=2)。
  # boot.kernel.sysctl."net.ipv4.conf.all.rp_filter" = 1;
  # boot.kernel.sysctl."net.ipv4.conf.wlp1s0.rp_filter" = 1;
}
