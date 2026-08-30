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
    text = ''
      esp=${lib.escapeShellArg efi.efiSysMountPoint}
      refind_dir="$esp/EFI/refind"
      private_key=${lib.escapeShellArg (toString lanzaboote.privateKeyFile)}
      public_key=${lib.escapeShellArg (toString lanzaboote.publicKeyFile)}

      work_dir="$(mktemp -d /run/refind-install.XXXXXX)"
      cleanup() {
        rm -rf -- "$work_dir"
      }
      trap cleanup EXIT

      install -d -m 0700 "$refind_dir/icons"

      if [[ -r "$private_key" && -r "$public_key" ]]; then
        sbsign \
          --key "$private_key" \
          --cert "$public_key" \
          --output "$work_dir/refind_x64.efi" \
          ${pkgs.refind}/share/refind/refind_x64.efi
      else
        echo "Secure Boot keys are not available yet; installing rEFInd unsigned for the initial boot." >&2
        install -m 0644 ${pkgs.refind}/share/refind/refind_x64.efi "$work_dir/refind_x64.efi"
      fi

      install -m 0644 "$work_dir/refind_x64.efi" "$refind_dir/refind_x64.efi.tmp"
      mv -f "$refind_dir/refind_x64.efi.tmp" "$refind_dir/refind_x64.efi"

      install -m 0644 ${refindConfig} "$refind_dir/refind.conf.tmp"
      mv -f "$refind_dir/refind.conf.tmp" "$refind_dir/refind.conf"

      # rEFInd loads volume badges and second-row tool icons from this directory.
      # Install the complete set so missing resources do not become striped boxes.
      cp --recursive --no-preserve=mode,ownership \
        ${pkgs.refind}/share/refind/icons/. \
        "$refind_dir/icons/"

      install -m 0644 \
        ${pkgs.nixos-icons}/share/icons/hicolor/128x128/apps/nix-snowflake.png \
        "$refind_dir/icons/os_nixos.png.tmp"
      mv -f "$refind_dir/icons/os_nixos.png.tmp" "$refind_dir/icons/os_nixos.png"

      ${lib.optionalString efi.canTouchEfiVariables ''
        export LC_ALL=C

        esp_source="$(findmnt -nro SOURCE --target "$esp")"
        esp_source="$(readlink -f "$esp_source")"
        esp_parent="$(lsblk -ndo PKNAME "$esp_source" | tr -d '[:space:]')"
        esp_partition="$(lsblk -ndo PARTN "$esp_source" | tr -d '[:space:]')"

        if [[ -z "$esp_parent" || -z "$esp_partition" ]]; then
          echo "Could not determine the disk and partition number for $esp_source." >&2
          exit 1
        fi

        efi_state="$(efibootmgr)"
        refind_id="$(printf '%s\n' "$efi_state" | sed -nE 's/^Boot([0-9A-Fa-f]{4})\*?[[:space:]]+rEFInd([[:space:]].*)?$/\1/p' | sed -n '1p')"

        if [[ -z "$refind_id" ]]; then
          efibootmgr \
            --create \
            --disk "/dev/$esp_parent" \
            --part "$esp_partition" \
            --loader '\EFI\refind\refind_x64.efi' \
            --label rEFInd
          efi_state="$(efibootmgr)"
          refind_id="$(printf '%s\n' "$efi_state" | sed -nE 's/^Boot([0-9A-Fa-f]{4})\*?[[:space:]]+rEFInd([[:space:]].*)?$/\1/p' | sed -n '1p')"
        fi

        if [[ -z "$refind_id" ]]; then
          echo "rEFInd was installed, but its UEFI boot entry could not be found." >&2
          exit 1
        fi

        refind_id="''${refind_id^^}"
        boot_order="$(printf '%s\n' "$efi_state" | sed -nE 's/^BootOrder:[[:space:]]*//p')"

        if [[ -n "$boot_order" ]]; then
          new_order="$refind_id"
          IFS=',' read -r -a boot_ids <<< "$boot_order"
          for boot_id in "''${boot_ids[@]}"; do
            boot_id="''${boot_id^^}"
            if [[ "$boot_id" != "$refind_id" ]]; then
              new_order+=",$boot_id"
            fi
          done

          if [[ "$new_order" != "$boot_order" ]]; then
            efibootmgr --bootorder "$new_order"
          fi
        fi
      ''}

      sync -f "$esp"
    '';
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
