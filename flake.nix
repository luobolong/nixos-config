{
  # Allow the first rebuild to download Noctalia from its official binary cache.
  nixConfig = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin-fuzzel = {
      url = "github:catppuccin/fuzzel";
      flake = false;
    };

    # The cachix branch always points at the latest revision built by Noctalia's
    # binary cache. Keep its own nixpkgs input so the cached derivation matches.
    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };

    rime-ice = {
      url = "github:iDvel/rime-ice";
      flake = false;
    };

    astronvim = {
      url = "github:AstroNvim/template";
      flake = false;
    };

    audiomonitor = {
      url = "github:luobolong/audiomonitor/7e2ff2fc38c12ce4f94e67dc11fc56a9f3454db6";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nixos-wsl,
      noctalia,
      ...
    }:
    let
      system = "x86_64-linux";
      hostname = "wsl";
      username = "ben";
    in
    {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs hostname username; };
        modules = [
          nixos-wsl.nixosModules.default
          home-manager.nixosModules.home-manager
          ./hosts/wsl
        ];
      };

      checks.${system}.wsl = self.nixosConfigurations.${hostname}.config.system.build.toplevel;

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
    };
}
