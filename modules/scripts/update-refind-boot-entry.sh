# shellcheck shell=bash
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

refind_id="${refind_id^^}"
boot_order="$(printf '%s\n' "$efi_state" | sed -nE 's/^BootOrder:[[:space:]]*//p')"

if [[ -n "$boot_order" ]]; then
  new_order="$refind_id"
  IFS=',' read -r -a boot_ids <<< "$boot_order"
  for boot_id in "${boot_ids[@]}"; do
    boot_id="${boot_id^^}"
    if [[ "$boot_id" != "$refind_id" ]]; then
      new_order+=",$boot_id"
    fi
  done

  if [[ "$new_order" != "$boot_order" ]]; then
    efibootmgr --bootorder "$new_order"
  fi
fi
