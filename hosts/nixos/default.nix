{
  inputs,
  username,
  ...
}:
{
  imports = [
    ./disk-config.nix
    ./hardware-configuration.nix
    ../../modules/clash-verge.nix
    ../../modules/core.nix
    ../../modules/desktop.nix
    ../../modules/flclash.nix
    ../../modules/refind.nix
    ../../modules/secrets.nix
    ../../modules/snapper.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs username; };
    sharedModules = [ inputs.noctalia.homeModules.default ];
    users.${username} = import ../../home;
  };
}
