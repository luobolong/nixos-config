{
  lib,
  pkgs,
  hostname,
  username,
  ...
}:
let
  # The declarative login password for both ben and root is q. Replace this
  # hash as soon as possible after installation.
  loginPasswordHash = "$6$R1okLc57kK.c4j7/$t7Vr4cPUATqr1LthGUK8rX1MePp8yKUPltzSzLNbWT7OaN153SYID5hrvb3hse.Mgh6g54v1PFYheRHPx/l8W1";

in
{
  networking = {
    hostName = hostname;
    networkmanager.enable = true;
    firewall.enable = false;
  };

  time.timeZone = "Asia/Taipei";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
  console.keyMap = "us";

  users = {
    # Force declarative password synchronization so this configuration remains
    # the single source of truth for account passwords.
    mutableUsers = false;
    users = {
      root.hashedPassword = loginPasswordHash;
      ${username} = {
        isNormalUser = true;
        description = username;
        hashedPassword = loginPasswordHash;
        extraGroups = [
          "networkmanager"
          "wheel"
          "video"
          "audio"
          "input"
          "dialout"
        ];
        shell = pkgs.zsh;
      };
    };
  };
  programs.zsh.enable = true;
  programs.nix-ld.enable = true;
  security.sudo.wheelNeedsPassword = true;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      # cc-switch 3.16.5 links rusqlite against the system SQLite but nixpkgs omits
      # it from buildInputs, so the build fails with "cannot find -lsqlite3" and
      # never reaches the binary cache. Drop this once nixpkgs adds the dependency.
      (final: prev: {
        cc-switch = prev.cc-switch.overrideAttrs (oldAttrs: {
          buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ final.sqlite ];
        });
      })
    ];
  };

  boot = {
    # Follow the latest Linux kernel series provided by nixos-unstable.
    kernelPackages = pkgs.linuxPackages_latest;

    loader = {
      # Lanzaboote takes over systemd-boot and generates a UKI for each system
      # generation.
      systemd-boot = {
        enable = lib.mkForce false;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
      # rEFInd handles the first-stage selection; keep only a short delay here
      # for choosing a NixOS system generation.
      timeout = 2;
    };

    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      configurationLimit = 10;

      # Generate keys on the first boot. Rebuild NixOS again afterward to sign
      # the UKIs.
      # Keep firmware key enrollment manual to avoid automatically modifying
      # UEFI keys on unknown motherboards.
      autoGenerateKeys.enable = true;
      autoEnrollKeys.enable = false;
    };

    tmp.cleanOnBoot = true;
  };

  services.fstrim.enable = true;
  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    bubblewrap
    git
    curl
    wget
    btrfs-assistant
    btrfs-progs
    disko
    sbctl
    vim
  ];

  system.stateVersion = "25.11";
}
