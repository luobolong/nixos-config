{
  pkgs,
  hostname,
  username,
  ...
}:
let
  # The declarative login password for both the normal user and root is q.
  # Replace this hash as soon as possible after installation.
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
      extra-substituters = [ "https://noctalia.cachix.org" ];
      extra-trusted-public-keys = [
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];
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

  services.fstrim.enable = true;
  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    btrfs-assistant
    btrfs-progs
    vim
  ];
  environment.pathsToLink = [ "/share/zsh" ];

  system.stateVersion = "25.11";
}
