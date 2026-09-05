{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.boot.refindChainloader;
  efi = config.boot.loader.efi;
  lanzaboote = config.boot.lanzaboote;

  windowsEfiPartuuid = toString cfg.windowsEfiPartuuid;
  validPartuuid =
    cfg.windowsEfiPartuuid != null
    &&
      builtins.match "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}" cfg.windowsEfiPartuuid
      != null;

  refindConfig = pkgs.writeText "refind.conf" ''
    timeout ${toString cfg.timeout}

    # Only show the two explicitly declared operating-system entries.
    scanfor manual
    showtools

    menuentry "Windows" {
      # Keep the icon on the rEFInd ESP, then switch volumes for bootmgfw.efi.
      icon \EFI\refind\icons\os_win8.png
      volume ${windowsEfiPartuuid}
      loader \EFI\Microsoft\Boot\bootmgfw.efi
    }

    menuentry "systemd-boot" {
      icon \EFI\refind\icons\os_nixos.png
      loader \EFI\systemd\systemd-bootx64.efi
    }
  '';

  refindInstaller = pkgs.writeShellApplication {
    name = "install-refind-chainloader";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.efibootmgr
      pkgs.gnused
      pkgs.sbsigntool
      pkgs.util-linux
    ];
    text = (
      lib.replaceStrings
        [
          "@esp@"
          "@privateKey@"
          "@publicKey@"
          "@refind@"
          "@refindConfig@"
          "@nixosIcons@"
          "@updateBootEntry@"
        ]
        [
          (lib.escapeShellArg efi.efiSysMountPoint)
          (lib.escapeShellArg (toString lanzaboote.privateKeyFile))
          (lib.escapeShellArg (toString lanzaboote.publicKeyFile))
          "${pkgs.refind}"
          "${refindConfig}"
          "${pkgs.nixos-icons}"
          (lib.optionalString efi.canTouchEfiVariables (
            builtins.readFile ./scripts/update-refind-boot-entry.sh
          ))
        ]
        (builtins.readFile ./scripts/install-refind-chainloader.sh)
    );
  };

  efiSysMountPoints = [ efi.efiSysMountPoint ] ++ lanzaboote.extraEfiSysMountPoints;
  lanzabooteInstallCommands = lib.concatMapStringsSep "\n" (efiSysMountPoint: ''
    PATH=${config.systemd.package}/lib/systemd:$PATH
    ${lanzaboote.installCommand} \
      ${lib.escapeShellArg "--public-key=${toString lanzaboote.publicKeyFile}"} \
      ${lib.escapeShellArg "--private-key=${toString lanzaboote.privateKeyFile}"} \
      ${lib.escapeShellArg efiSysMountPoint} \
      /nix/var/nix/profiles/system-*-link
  '') efiSysMountPoints;

  combinedInstaller = pkgs.writeShellScript "install-lanzaboote-and-refind" ''
    set -eu
    ${lanzabooteInstallCommands}
    ${lib.getExe refindInstaller}
  '';
in
{
  options.boot.refindChainloader = {
    enable = lib.mkEnableOption "rEFInd as a two-entry front end for Windows and systemd-boot";

    timeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = "Seconds before rEFInd starts the default systemd-boot entry.";
    };

    windowsEfiPartuuid = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "991a77db-c316-4f75-b9df-bc05e179a798";
      description = "GPT partition UUID of the ESP containing the Windows boot manager.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lanzaboote.enable;
        message = "boot.refindChainloader requires boot.lanzaboote.enable.";
      }
      {
        assertion = validPartuuid;
        message = "boot.refindChainloader.windowsEfiPartuuid must be a GPT partition UUID.";
      }
      {
        assertion = pkgs.stdenv.hostPlatform.isx86_64;
        message = "This rEFInd chainloader configuration currently supports x86_64 only.";
      }
      {
        assertion = !lanzaboote.measuredBoot.enable;
        message = "boot.refindChainloader does not currently support Lanzaboote measured boot.";
      }
    ];

    # Lanzaboote normally owns this hook. Run it first, then install and sign
    # rEFInd so every rebuild leaves rEFInd first in the UEFI BootOrder.
    boot.loader.external.installHook = lib.mkForce combinedInstaller;

    environment.systemPackages = [
      pkgs.efibootmgr
      pkgs.refind
    ];
  };
}
