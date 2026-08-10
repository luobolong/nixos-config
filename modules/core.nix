{ config, lib, pkgs, hostname, username, ... }:
{
  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Taipei";
  i18n.defaultLocale = "zh_CN.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };
  console.keyMap = "us";

  users.mutableUsers = true;
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "networkmanager" "wheel" "video" "audio" "input" ];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;
  security.sudo.wheelNeedsPassword = true;

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
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

  nixpkgs.config.allowUnfree = true;

  boot = {
    loader = {
      refind = {
        enable = true;
        maxGenerations = 10;
      };
      efi.canTouchEfiVariables = true;
      timeout = 5;
    };
    tmp.cleanOnBoot = true;
  };

  services.fstrim.enable = true;
  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    btrfs-progs
    disko
    vim
  ];

  system.stateVersion = "25.11";
}
