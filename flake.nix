{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
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

    # main 分支目前是 Noctalia v5（Beta）。flake.lock 会固定实际版本。
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rime-ice = {
      url = "github:iDvel/rime-ice";
      flake = false;
    };

    astronvim = {
      url = "github:AstroNvim/template";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, disko, lanzaboote, noctalia, ... }:
    let
      system = "x86_64-linux";
      hostname = "nixos";
      username = "ben";
    in {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs hostname username; };
        modules = [
          disko.nixosModules.disko
          lanzaboote.nixosModules.lanzaboote
          home-manager.nixosModules.home-manager
          noctalia.nixosModules.default
          ./hosts/nixos
        ];
      };

      checks.${system}.nixos = self.nixosConfigurations.${hostname}.config.system.build.toplevel;

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
    };
}
