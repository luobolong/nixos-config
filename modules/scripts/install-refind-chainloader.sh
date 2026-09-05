# shellcheck shell=bash
esp=@esp@
refind_dir="$esp/EFI/refind"
private_key=@privateKey@
public_key=@publicKey@

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
    @refind@/share/refind/refind_x64.efi
else
  echo "Secure Boot keys are not available yet; installing rEFInd unsigned for the initial boot." >&2
  install -m 0644 @refind@/share/refind/refind_x64.efi "$work_dir/refind_x64.efi"
fi

install -m 0644 "$work_dir/refind_x64.efi" "$refind_dir/refind_x64.efi.tmp"
mv -f "$refind_dir/refind_x64.efi.tmp" "$refind_dir/refind_x64.efi"

install -m 0644 @refindConfig@ "$refind_dir/refind.conf.tmp"
mv -f "$refind_dir/refind.conf.tmp" "$refind_dir/refind.conf"

# rEFInd loads volume badges and second-row tool icons from this directory.
# Install the complete set so missing resources do not become striped boxes.
cp --recursive --no-preserve=mode,ownership \
  @refind@/share/refind/icons/. \
  "$refind_dir/icons/"

install -m 0644 \
  @nixosIcons@/share/icons/hicolor/128x128/apps/nix-snowflake.png \
  "$refind_dir/icons/os_nixos.png.tmp"
mv -f "$refind_dir/icons/os_nixos.png.tmp" "$refind_dir/icons/os_nixos.png"

@updateBootEntry@

sync -f "$esp"
