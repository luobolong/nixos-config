{
  inputs,
  username,
  ...
}:
{
  imports = [ ../../modules/wsl.nix ];

  wsl = {
    enable = true;
    defaultUser = username;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit inputs username;
      wsl = true;
    };
    sharedModules = [ inputs.noctalia.homeModules.default ];
    users.${username} = import ../../home/wsl.nix;
  };
}
