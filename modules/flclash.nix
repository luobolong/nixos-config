{ pkgs, ... }:
let
  # 与 home/default.nix 中相同的 callPackage 参数 → 同一个 store path。
  flclash = pkgs.callPackage ../packages/flclash.nix { };
in
{
  # TUN 模式需要内核 tun 模块（本机为 CONFIG_TUN=m）。
  boot.kernelModules = [ "tun" ];

  # 只给真正创建 TUN 网卡的核心进程授权。不能包装外层
  # FlClash 启动器，否则 capability 会先传给 bubblewrap，导致 bwrap
  # 以 "Unexpected capabilities but not setuid" 拒绝启动。
  security.wrappers.FlClashCore = {
    owner = "root";
    group = "root";
    capabilities = "cap_net_admin=+ep";
    source = "${flclash}/libexec/flclash/FlClashCore.unwrapped";
  };

  # TUN 路由常与 strict rp_filter 冲突。
  networking.firewall.checkReversePath = "loose";
}
