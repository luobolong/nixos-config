{ lib, username, ... }:
let
  manualConfig = {
    ALLOW_USERS = [ username ];
    SYNC_ACL = true;
    TIMELINE_CREATE = false;
    TIMELINE_CLEANUP = false;
    NUMBER_CLEANUP = false;
    EMPTY_PRE_POST_CLEANUP = false;
  };
in
{
  services.snapper = {
    snapshotRootOnBoot = false;
    configs = {
      root = manualConfig // {
        SUBVOLUME = "/";
      };
      home = manualConfig // {
        SUBVOLUME = "/home";
      };
    };
  };

  # The Snapper module enables these timers whenever configs are declared.
  # Leave them available for manual use without starting them at boot.
  systemd.timers.snapper-timeline.wantedBy = lib.mkForce [ ];
  systemd.timers.snapper-cleanup.wantedBy = lib.mkForce [ ];

  environment.pathsToLink = [ "/share/snapper" ];
}
