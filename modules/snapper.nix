{ pkgs, ... }:
{
  # Users manage /etc/snapper and /etc/sysconfig/snapper through Snapper or
  # Btrfs Assistant. Expose the upstream units without enabling any timers.
  environment.systemPackages = [ pkgs.snapper ];
  environment.pathsToLink = [ "/share/snapper" ];
  services.dbus.packages = [ pkgs.snapper ];
  systemd.packages = [ pkgs.snapper ];
}
