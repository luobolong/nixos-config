{ config, lib, pkgs, hostname, username, ... }:
let
  # ben 与 root 的声明式登录密码均为 q。安装完成后应尽快替换此哈希。
  loginPasswordHash = "$6$R1okLc57kK.c4j7/$t7Vr4cPUATqr1LthGUK8rX1MePp8yKUPltzSzLNbWT7OaN153SYID5hrvb3hse.Mgh6g54v1PFYheRHPx/l8W1";
in
{
  networking.hostName = hostname;
  networking.networkmanager.enable = true;

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
    # 强制同步声明式密码，确保声明配置是账户密码的唯一来源。
    mutableUsers = false;
    users = {
      root.hashedPassword = loginPasswordHash;
      ${username} = {
        isNormalUser = true;
        description = username;
        hashedPassword = loginPasswordHash;
        extraGroups = [ "networkmanager" "wheel" "video" "audio" "input" ];
        shell = pkgs.zsh;
      };
    };
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
      # Lanzaboote 接管 systemd-boot，并为每个系统代次生成 UKI。
      systemd-boot = {
        enable = lib.mkForce false;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
      timeout = 5;
    };

    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      configurationLimit = 10;

      # 首次启动时生成密钥。生成后需再次 nixos-rebuild 才会签名 UKI。
      # 固件密钥注册保持手动，避免在未知主板上自动修改 UEFI 密钥。
      autoGenerateKeys.enable = true;
      autoEnrollKeys.enable = false;
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
    sbctl
    vim
  ];
  environment.pathsToLink = [ "/share/zsh" ];

  system.stateVersion = "25.11";
}
