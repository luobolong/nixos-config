{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    audiomonitor = {
      url = "github:luobolong/audiomonitor";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bili-danmaku-tui = {
      url = "github:Youthdreamer/bili-danmaku-tui";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    linuxqq-wayland-fix = {
      url = "github:SHORiN-KiWATA/linuxqq-wayland-fix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    astronvim = {
      url = "github:AstroNvim/template";
      flake = false;
    };

    turing-screen = {
      url = "github:luobolong/turing-smart-screen-qt";
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
      sops-nix,
      ...
    }:
    let
      system = "x86_64-linux";
      hostname = "nixos";
      username = "ben";
      packagePkgs = self.nixosConfigurations.${hostname}.pkgs;
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
          inputs.linuxqq-wayland-fix.nixosModules.default
          inputs.turing-screen.nixosModules.default
          ./hosts/nixos
        ];
      };

      checks.${system}.nixos = self.nixosConfigurations.${hostname}.config.system.build.toplevel;

      packages.${system} =
        (import ./packages {
          inherit inputs;
          pkgs = packagePkgs;
        })
        // {
          inherit (packagePkgs)
            chatgpt
            claude-code
            codex
            deepseek-harness
            noctalia
            rime-ice
            ;
          inherit (packagePkgs.obs-studio-plugins) obs-bilibili-stream;
          turing-screen = inputs.turing-screen.packages.${system}.default;
        };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
    };
}
