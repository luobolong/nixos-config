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

    # Claude Code uses nixpkgs' package definition. Keep this input separate so
    # it can follow unstable independently from the system nixpkgs lock.
    nixpkgs-claude.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin-fuzzel = {
      url = "github:catppuccin/fuzzel";
      flake = false;
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
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

    linuxqq-clipsync = {
      url = "github:SHORiN-KiWATA/linuxqq-clipsync";
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
      disko,
      lanzaboote,
      noctalia,
      sops-nix,
      ...
    }:
    let
      system = "x86_64-linux";
      hostname = "nixos";
      username = "ben";
    in
    {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs hostname username; };
        modules = [
          disko.nixosModules.disko
          lanzaboote.nixosModules.lanzaboote
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          noctalia.nixosModules.default
          ./hosts/nixos
        ];
      };

      checks.${system}.nixos = self.nixosConfigurations.${hostname}.config.system.build.toplevel;

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
    };
}
