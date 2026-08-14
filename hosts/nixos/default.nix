{ inputs, username, ... }:
{
  imports = [
    ./disk-config.nix
    ./hardware-configuration.nix
    ../../modules/core.nix
    ../../modules/desktop.nix
    ../../modules/refind.nix
    ../../modules/secrets.nix
    ../../modules/snapper.nix
  ];

  boot.refindChainloader = {
    enable = true;
    # Windows Boot Manager 位于独立的 ESP；使用 PARTUUID 可避免 rEFInd 找错分区。
    windowsEfiPartuuid = "991a77db-c316-4f75-b9df-bc05e179a798";
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs username; };
    sharedModules = [ inputs.noctalia.homeModules.default ];
    users.${username} = import ../../home;
  };
}
