{ username, ... }:
let
  commonConfig = {
    ALLOW_USERS = [ username ];
    SYNC_ACL = true;

    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_LIMIT_HOURLY = 24;
    TIMELINE_LIMIT_DAILY = 7;
    TIMELINE_LIMIT_WEEKLY = 4;
    TIMELINE_LIMIT_MONTHLY = 6;
    TIMELINE_LIMIT_YEARLY = 0;
  };
in
{
  services.snapper = {
    snapshotInterval = "hourly";
    cleanupInterval = "1d";
    persistentTimer = true;

    configs = {
      root = commonConfig // {
        SUBVOLUME = "/";
      };
      home = commonConfig // {
        SUBVOLUME = "/home";
      };
    };
  };
}
