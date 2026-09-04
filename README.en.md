# NixOS Configuration

Personal NixOS and Home Manager configuration for an AMD x86-64 workstation and a Lenovo IdeaPad Pro 5 14APH8 laptop.

[中文](README.md)

---

## English

### Overview

This repository is a complete personal machine configuration, not a hardware-neutral module library. It manages NixOS, Home Manager, the boot chain, storage mounts, desktop sessions, development tools, and daily applications.

| Item | Current value |
|---|---|
| Architecture | <code>x86_64-linux</code> |
| Flake output | <code>nixosConfigurations.wsl</code> |
| Host name | <code>wsl</code> |
| User | <code>ben</code> |
| Nixpkgs | <code>nixos-unstable</code> |
| NixOS / Home Manager state version | <code>25.11</code> |
| Time zone | <code>Asia/Taipei</code> |
| Graphics | WSLg (Wayland/X11 applications) |
| Login entry | Windows Terminal / WSLg |
| System filesystem | WSL-managed virtual ext4 filesystem |
| Boot | NixOS-WSL module (no EFI management) |

Highlights:

- A single Flake composes NixOS-WSL, Home Manager, and shared desktop configuration.
- WSLg runs Linux GUI applications; Hyprland, niri, and Noctalia configuration is retained but no nested session starts automatically.
- Fcitx5 with Rime Ice provides Chinese and English input.
- Networking, kernel, storage, and boot are managed by WSL/Windows.
- Local packages cover the ChatGPT Linux app, DeepSeek Harness, Linux QQ clipboard synchronization, and AudioMonitor.
- Wayland, Electron, Qt/KDE, and GTK applications share a Catppuccin Mocha-oriented desktop.

### Branch model

<code>master</code> is the Disko-based AMD x86-64 baseline. <code>laptop</code> is the device-specific configuration for the current Lenovo laptop. <code>wsl</code> is the NixOS-WSL configuration for WSL2. <code>master</code> is the common base for all variants; host-specific differences stay in their respective host directories and modules.

| Scope | <code>master</code> | <code>laptop</code> | <code>wsl</code> |
|---|---|---|---|
| Intended target | Fresh-disk deployment baseline | Installed Lenovo IdeaPad Pro 5 14APH8 | WSL2 development environment |
| Disk management | Imports Disko through the Flake, system modules, and maintenance packages | Does not import Disko; only mounts existing filesystems | WSL manages the virtual disk; no partitions or mounts are declared |
| Boot | UEFI, rEFInd, and Lanzaboote | UEFI, rEFInd, and Lanzaboote | NixOS-WSL module; no EFI or bootloader management |
| Desktop session | greetd + Hyprland/niri | greetd + Hyprland/niri | WSLg; no nested compositor is started by default |
| Hardware services | AMDGPU, Bluetooth, PipeWire, and UDisks2 | AMDGPU, Bluetooth, PipeWire, and UDisks2 | No physical hardware services; WSLg application support remains available |
| Snapshots | Btrfs subvolumes and Snapper | Existing Btrfs subvolumes and Snapper | No Snapper; use WSL export/backup mechanisms |
| Windows dual boot | Uses Windows ESP PARTUUID <code>991a77db-c316-4f75-b9df-bc05e179a798</code>; the ESP should be on another disk that Disko will not erase | Uses <code>084dbc6c-e077-48f9-b6d5-ccd76d8f1d42</code> for the Windows ESP on the same SSD | Not applicable; Windows starts WSL |

Inspect the exact committed branch delta with:

~~~bash
git diff --stat master...laptop
git diff master...laptop -- flake.nix home/default.nix hosts/nixos modules/core.nix
~~~

### WSL2 usage

The <code>wsl</code> branch uses the <code>nixosConfigurations.wsl</code> output. It reuses the shared Home Manager configuration and development tools, while leaving out Disko, EFI/Secure Boot, rEFInd, greetd, Bluetooth, Btrfs, and Snapper. The physical-machine installation sections below apply only to <code>master</code>/<code>laptop</code>. After installing NixOS-WSL, run from the repository:

~~~bash
git switch wsl
nix flake lock
sudo nixos-rebuild switch --flake .#wsl
~~~

Import the distribution according to the NixOS-WSL instructions; the login user is <code>ben</code>. WSLg provides the Windows-side Wayland/X11 bridge, so Linux GUI applications can be launched from WSL. This configuration does not start Hyprland, niri, or a Noctalia session inside WSL.

### Repository layout

~~~text
.
├── .sops.yaml                        # GPG and Age recipient rules
├── flake.nix                         # Inputs, host output, checks, formatter
├── flake.lock
├── hosts/nixos/
│   ├── default.nix                   # Host imports and Home Manager wiring
│   ├── disk-config.nix               # Branch-specific provisioning or mounts
│   ├── hardware-configuration.nix    # AMD hardware, ESP, and laptop EDID
│   └── lenovo-14aph8-edid.hex        # Corrected EDID on the laptop branch
├── hosts/wsl/
│   └── default.nix                   # NixOS-WSL host entry
├── modules/
│   ├── core.nix                      # Users, Nix, kernel, SSH, system tools
│   ├── desktop.nix                   # Wayland sessions, audio, Bluetooth, IME, fonts
│   ├── refind.nix                    # rEFInd and Lanzaboote installer chain
│   ├── snapper.nix                   # Root and home snapshot policy
│   ├── clash-verge.nix               # Clash Verge service and TUN settings
│   ├── secrets.nix                   # sops-nix Age key source
│   ├── wsl.nix                        # WSL2 system base configuration
│   ├── fonts.conf                    # Fontconfig font priorities
│   └── patches/                      # Local package fixes
├── home/
│   ├── default.nix                   # Home Manager, applications, theming, services
│   ├── hyprland.lua                  # Hyprland Lua configuration
│   ├── niri.kdl                      # niri configuration
│   ├── niri-smart-direction.sh       # Smart directional actions for niri
│   └── zsh.nix                       # Zsh, Starship, fzf, terminal tools
└── packages/
    ├── chatgpt.nix                   # Official ChatGPT Linux binary wrapper
    ├── deepseek-harness.nix          # DeepSeek Harness NPM build
    └── deepseek-harness/package-lock.json
~~~

### Pre-install customization

#### Host name and user name

Change these values in <code>flake.nix</code>:

~~~nix
let
  system = "x86_64-linux";
  hostname = "nixos";
  username = "ben";
in
~~~

- <code>hostname</code> controls both <code>networking.hostName</code> and the Flake output name. After changing it to <code>my-host</code>, installation and rebuild commands must target <code>.#my-host</code>.
- <code>hosts/nixos</code> is a fixed source directory. It does not change automatically and does not need to be renamed just because the host name changes.
- <code>username</code> is passed to the NixOS user and Home Manager configuration. After changing it, review the Git name, email, signing key, and other personal settings in <code>home/default.nix</code>.
- Replace <code>ben</code> and <code>nixos</code> in the command examples in this document with the new values.

#### Accounts and passwords

<code>modules/core.nix</code> sets <code>users.mutableUsers = false</code>. root and the normal user share the <code>loginPasswordHash</code> variable. The repository currently contains the hash for the weak password <code>q</code>, which is only a placeholder. Generate a new hash and replace it before installation:

~~~bash
nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512
~~~

Split this into two hash variables if root and the normal user should have different passwords. OpenSSH is enabled while the firewall is disabled, so also adjust <code>services.openssh</code>, authentication, and <code>networking.firewall</code> for the target network.

#### CPU, graphics, and laptop panel

<code>hosts/nixos/hardware-configuration.nix</code> assumes an AMD CPU and AMDGPU. It enables <code>kvm-amd</code>, AMD microcode, early AMDGPU KMS, and 32-bit graphics support. Intel, NVIDIA, or other hardware needs corresponding changes.

The <code>laptop</code> branch additionally loads a corrected EDID for the Lenovo IdeaPad Pro 5 14APH8. Only the matching 2880×1800 panel needs these settings. On another device, remove the EDID firmware build, the <code>drm.edid_firmware</code> kernel parameter, and the related firmware path.

#### Windows ESP

rEFInd locates Windows Boot Manager through the GPT PARTUUID of the Windows ESP. Find the actual value and update <code>windowsEfiPartuuid</code> in <code>hosts/nixos/hardware-configuration.nix</code>:

~~~bash
lsblk -o PATH,SIZE,FSTYPE,LABEL,PARTUUID,PARTLABEL,MOUNTPOINTS
~~~

This is the partition PARTUUID, not the filesystem UUID. Back up the BitLocker recovery key and important data before installation. For dual-boot machines, disable Windows Fast Startup and suspend BitLocker before repartitioning or changing boot keys.

### Required pre-deployment review

Do not deploy this repository unchanged without checking all of the following:

1. Replace the default password hash and review the host name, user name, Git identity, and sops recipients.
2. OpenSSH is enabled while the firewall is disabled; the network and SSH authentication policy must make this acceptable.
3. The <code>master</code> Disko device is no longer <code>/dev/disk/by-id/CHANGE_ME</code>, and the selected disk is definitely safe to erase in full.
4. The labels and Btrfs subvolumes expected by <code>laptop</code> already exist; that branch does not create them.
5. The Windows ESP PARTUUID matches the current machine, and the Windows ESP is not the Disko target.
6. The <code>laptop</code> EDID override is only enabled on the matching Lenovo panel.
7. The custom boot install hook updates Lanzaboote and rEFInd files on the ESP and, when EFI variable writes are allowed, puts rEFInd first in UEFI BootOrder.
8. A bootable installer, full backup, and any necessary firmware or BitLocker recovery method are ready.

### Select and validate a branch

~~~bash
git clone https://github.com/luobolong/nixos-config.git
cd nixos-config

# Select one deployment target
git switch master
# or
git switch laptop
# or
git switch wsl

nix flake check
nix build .#nixosConfigurations.wsl.config.system.build.toplevel --no-link
~~~

If <code>hostname</code> was changed, replace <code>nixos</code> in this and later commands with the new Flake output name. Flakes only see files tracked by Git or added to its index. After creating a local configuration file, explicitly run <code>git add FILE_PATH</code> before validation.

### Installation

The physical-machine installation and maintenance commands below apply only to <code>master</code>/<code>laptop</code>; use the WSL2 section above for <code>wsl</code>.

The following procedures assume that the installer was booted in UEFI mode. Connect to the network and confirm the environment first:

~~~bash
sudo systemctl start NetworkManager
nmtui
test -d /sys/firmware/efi && echo UEFI || echo "Not booted in UEFI mode"
~~~

#### master: install a fresh disk with Disko

> **Warning:** this procedure destroys the entire disk referenced by <code>hosts/nixos/disk-config.nix</code>. It cannot preserve an existing Windows installation on that disk. The current <code>master</code> setup assumes that the Windows ESP is on another disk that Disko will not touch.

1. Inspect stable device paths and repeatedly verify the target by capacity, model, and serial number:

   ~~~bash
   ls -l /dev/disk/by-id/
   lsblk -o PATH,SIZE,MODEL,SERIAL,FSTYPE,LABEL,PARTUUID,MOUNTPOINTS
   ~~~

2. Replace <code>/dev/disk/by-id/CHANGE_ME</code> in <code>hosts/nixos/disk-config.nix</code> with the complete, verified by-id path. The default layout is a 2 GiB ESP, 64 GiB swap, and a Btrfs partition using the remaining space.

3. Review the configuration again, then run Disko in destroy, format, and mount mode:

   ~~~bash
   nix flake check
   sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- \
     --mode destroy,format,mount ./hosts/nixos/disk-config.nix
   findmnt -R /mnt
   ~~~

4. Confirm that <code>/mnt</code>, <code>/mnt/nix</code>, <code>/mnt/home</code>, and <code>/mnt/boot</code> all come from the target disk, then install:

   ~~~bash
   sudo nixos-install --flake .#nixos --no-root-passwd
   sudo reboot
   ~~~

The upstream quickstart also states that this procedure wipes the disk and does not support a dual-boot layout. Read the [Disko Quickstart](https://github.com/nix-community/disko/blob/master/docs/quickstart.md) before running it.

#### laptop: install manually in free space beside Windows

This branch does not run Disko. It assumes that Windows already uses UEFI/GPT and that only the following new partitions are created in previously unallocated space:

| Partition | Size | Format/label | Purpose |
|---|---:|---|---|
| NixOS ESP | 2 GiB | FAT32, <code>NIXBOOT</code> | <code>/boot</code> and multiple UKI generations |
| Swap | 32 GiB | swap, <code>nixos-swap</code> | Swap and resume |
| System | Remaining space | Btrfs, <code>nixos</code> | root, nix, and home subvolumes |

1. Identify the target disk and create three new partitions only in the unallocated space released by Windows. Do not format the Windows ESP, MSR, system, or recovery partitions:

   ~~~bash
   ls -l /dev/disk/by-id/
   lsblk -o PATH,SIZE,MODEL,FSTYPE,LABEL,PARTUUID,PARTLABEL,MOUNTPOINTS
   sudo cfdisk /dev/disk/by-id/DEVICE
   ~~~

2. Format only the three newly created partitions, replacing the sample device names with their actual paths:

   ~~~bash
   sudo mkfs.fat -F 32 -n NIXBOOT /dev/NEW_ESP
   sudo mkswap -L nixos-swap /dev/NEW_SWAP
   sudo mkfs.btrfs -f -L nixos /dev/NEW_BTRFS
   ~~~

3. Create the Btrfs subvolumes required by the configuration:

   ~~~bash
   sudo mount -o subvolid=5 /dev/disk/by-label/nixos /mnt
   sudo btrfs subvolume create /mnt/@root
   sudo btrfs subvolume create /mnt/@root/.snapshots
   sudo btrfs subvolume create /mnt/@nix
   sudo btrfs subvolume create /mnt/@home
   sudo btrfs subvolume create /mnt/@home/.snapshots
   sudo umount /mnt
   ~~~

4. Mount the system exactly as declared:

   ~~~bash
   sudo mount -o subvol=@root,compress=zstd,noatime /dev/disk/by-label/nixos /mnt
   sudo mkdir -p /mnt/nix /mnt/home /mnt/boot
   sudo mount -o subvol=@nix,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/nix
   sudo mount -o subvol=@home,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/home
   sudo mount -o umask=0077 /dev/disk/by-label/NIXBOOT /mnt/boot
   sudo swapon /dev/disk/by-label/nixos-swap
   findmnt -R /mnt
   swapon --show
   ~~~

5. Temporarily mount the existing Windows ESP and verify its boot file and PARTUUID. Do not format it:

   ~~~bash
   sudo mkdir -p /mnt/windows-esp
   sudo mount /dev/WINDOWS_ESP /mnt/windows-esp
   test -f /mnt/windows-esp/EFI/Microsoft/Boot/bootmgfw.efi
   lsblk -no PARTUUID /dev/WINDOWS_ESP
   sudo umount /mnt/windows-esp
   ~~~

6. Put that PARTUUID in <code>hosts/nixos/hardware-configuration.nix</code>. After verifying the labels and subvolumes, install:

   ~~~bash
   ls -l /dev/disk/by-label/NIXBOOT
   ls -l /dev/disk/by-label/nixos-swap
   ls -l /dev/disk/by-label/nixos
   sudo btrfs subvolume list /mnt
   sudo nixos-install --flake .#nixos --no-root-passwd
   sudo reboot
   ~~~

Keep Secure Boot disabled for the first reboot with either installation method. Machine-specific signing keys are generated only during the first boot, so the initial ESP contents may not all be signed yet.

### Apply the configuration

On an already running NixOS target:

~~~bash
sudo nixos-rebuild switch --flake .#nixos
~~~

To prepare the next boot without switching the running system:

~~~bash
sudo nixos-rebuild boot --flake .#nixos
~~~

Use <code>.#NEW_HOSTNAME</code> if the host name was changed. Every rebuild runs the custom boot install hook and updates the Lanzaboote and rEFInd files. rEFInd exposes only two manually defined entries:

- Windows Boot Manager.
- systemd-boot, which selects a NixOS system generation.

### Secure Boot

The configuration enables Lanzaboote and automatically creates signing keys under <code>/var/lib/sbctl</code>. Firmware key enrollment is intentionally manual. Use the following sequence:

1. Keep Secure Boot disabled and complete the first NixOS boot. Check the automatic key service and sbctl state:

   ~~~bash
   systemctl status generate-sb-keys.service --no-pager
   sudo sbctl status
   ~~~

2. After the keys exist, build the boot entries again and inspect signatures:

   ~~~bash
   sudo nixos-rebuild boot --flake .#nixos
   sudo sbctl verify
   ~~~

   Lanzaboote uses signed UKIs named like <code>/boot/EFI/Linux/nixos-generation-*.efi</code>. <code>sbctl verify</code> may still report raw <code>/boot/EFI/nixos/kernel-*.efi</code> files as unsigned. Focus on the UKI, systemd-boot, and rEFInd files that are actually in the boot chain.

3. Reboot into firmware settings and put Secure Boot into Setup Mode. Firmware commonly does this by deleting the Platform Key (PK). Do not clear dbx or indiscriminately delete all firmware keys. Keep the BitLocker recovery key and a firmware recovery plan available.

4. Return to NixOS with Secure Boot still disabled but Setup Mode active, then enroll the local keys while retaining Microsoft certificates:

   ~~~bash
   sudo sbctl enroll-keys --microsoft
   ~~~

5. Enter firmware again, enable Secure Boot, boot NixOS, and verify:

   ~~~bash
   bootctl status
   sudo sbctl status
   ~~~

Retaining Microsoft certificates helps Windows Boot Manager and some hardware option ROMs continue to boot. Never commit the private keys in <code>/var/lib/sbctl</code> or store them in a public backup. Secure Boot authenticates the boot chain; it is not disk encryption, and the current storage setup does not enable full-disk encryption. See the [Lanzaboote setup guide](https://github.com/nix-community/lanzaboote/blob/master/docs/getting-started/prepare-your-system.md) for background.

### First-login checks

After entering the graphical session for the first time:

- Start both Hyprland and niri once from Noctalia Greeter and verify login, locking, logout, and login again.
- Run <code>hyprctl monitors</code> or <code>niri msg outputs</code> in the corresponding session. On <code>laptop</code>, confirm that the internal display offers 2880×1800 at 120 Hz.
- Inspect EDID and AMDGPU messages with <code>journalctl -b -k | grep -Ei 'edid|displayid|amdgpu'</code>.
- Toggle Fcitx5/Rime with <code>Ctrl + Space</code> and select the Rime Ice schema with <code>F4</code>. If the candidate window fails, run <code>fcitx5 -r</code> and <code>fcitx5-configtool</code>.
- Check <code>systemctl --user --failed</code> and <code>systemctl --user status noctalia</code>, and make sure Noctalia, Linux QQ clipboard synchronization, and other user services did not fail.
- Before first use of Claude Code, Codex, or Gemini CLI, add and enable the corresponding API provider in CC Switch. This configuration does not store those service tokens.
- Run <code>nvim</code> once so AstroNvim can complete plugin initialization.
- Recheck <code>sudo sbctl status</code>, the Windows boot entry, audio, Bluetooth, suspend, and resume.

### Routine maintenance

~~~bash
# Format Nix files
nix fmt

# Run the full Flake check
nix flake check

# Build only the Home Manager generation
nix build .#nixosConfigurations.nixos.config.home-manager.users.ben.home.activationPackage --no-link

# Update inputs; review flake.lock before committing
nix flake update

# Compare system closures
nix build .#nixosConfigurations.nixos.config.system.build.toplevel
nvd diff /run/current-system result
~~~

The system removes Nix store generations older than seven days and optimizes the store weekly. Snapper creates hourly timeline snapshots for <code>/</code> and <code>/home</code>, retaining 24 hourly, 7 daily, 4 weekly, and 6 monthly snapshots. Replace the host and user attribute names above after changing either value.

### Data and backups

root and Home use separate persistent Btrfs subvolumes, and <code>XDG_PROJECTS_DIR</code> points to <code>~/Workspace</code>. Inspect space and snapshots with:

~~~bash
sudo btrfs filesystem usage /
snapper -c root list
snapper -c home list
systemctl list-timers 'snapper-*'
~~~

Snapper snapshots are useful for local rollback, but they are not an off-machine backup. Back up user data, uncommitted local configuration, the Secure Boot keys under <code>/var/lib/sbctl</code>, and the host SSH Ed25519 private key used to decrypt sops secrets. None of these private keys should enter a public repository.

### Desktop and user environment

| Area | Configuration |
|---|---|
| Sessions | Noctalia Greeter offers Hyprland and niri |
| Shell | Zsh vi mode, shared history, fzf, zoxide, eza, bat, lf |
| Prompt | Starship with OS, directory, Git state, and language versions |
| Terminal | Kitty, JetBrains Mono Nerd Font, Catppuccin Mocha, 90% opacity |
| File manager | Dolphin with Kvantum, compact toolbar, and right-side information panel |
| Launcher/bar/notifications | Noctalia; Mako and legacy network/Bluetooth tray autostart are disabled |
| Input method | Fcitx5 + Rime Ice with a horizontal list of seven candidates per page |
| Theme | Catppuccin Mocha Mauve, Papirus Dark, 32 px Adwaita cursor |
| Editors | AstroNvim with absolute line numbers, VS Code, JetBrains IDEs |
| Defaults | Kitty for terminals, Dolphin for directories, Firefox for the web, VS Code for text, Okular for PDF, Gwenview for images, mpv for media, Ark for archives |
| Audio | PipeWire with ALSA, 32-bit ALSA, and PulseAudio compatibility |
| Wayland tools | GTK portal, wl-clipboard, Satty, grim/slurp, nwg-displays |
| Network proxy | Clash Verge uses service mode and TUN mode but does not autostart |

Desktop applications include Firefox, Spotify, QQ, LocalSend, OBS Studio, Mission Center, Pavucontrol, AudioMonitor, ChatGPT, Okular, Gwenview, Ark, VS Code, IntelliJ IDEA, DataGrip, and GoLand.

Development and maintenance tools include GCC, CMake, Make, pkg-config, Node.js, Python, OpenJDK 25, Lua language server, nil, nixfmt, ShellCheck, Codex, Claude Code, DeepSeek Harness, sops, nh, nvd, and nix-output-monitor.

Installed font families cover Inter, Source Serif, Noto CJK/Emoji, Sarasa Gothic, Cousine Nerd Font, and JetBrains Mono Nerd Font.

### Hyprland key bindings

#### Windows, focus, and applications

| Binding | Action |
|---|---|
| <code>Super + Q</code> / <code>Alt + F4</code> | Close the active window |
| <code>Super + Alt + F4</code> | Force-kill the active window |
| <code>Super + W</code> | Toggle floating |
| <code>Super + Shift + W</code> | Set floating and toggle pinning |
| <code>Super + G</code> | Toggle window grouping |
| <code>Super + Ctrl + H/L</code> | Select the previous/next group member |
| <code>Super + J</code> | Toggle the Dwindle split direction |
| <code>Super + D</code> / <code>Shift + F11</code> | Toggle fullscreen |
| <code>Super + M</code> | Toggle maximized state |
| <code>Super + Arrow</code> | Move focus in a direction |
| <code>Super + Ctrl + Shift + Arrow</code> | Move the active window |
| <code>Super + Shift + Arrow</code> | Resize in 50 px steps |
| <code>Super + left mouse</code> / <code>Super + Z</code> | Drag a window |
| <code>Super + right mouse</code> / <code>Super + X</code> | Resize a window |
| <code>Alt + Tab</code> | Open the Noctalia window switcher |
| <code>Super + L</code> | Lock with Hyprlock |
| <code>Super + Alt + Z</code> | Toggle pointer-centered zoom between 1× and 2× |
| <code>Super + Alt + wheel</code> | Adjust zoom in 0.25× steps |
| <code>Super + T/E/C/B/F</code> | Open Kitty / Dolphin / VS Code / Firefox |
| <code>Ctrl + Shift + Escape</code> | Open Mission Center |
| <code>Super + A/V</code> | Open the Noctalia launcher / clipboard |
| <code>Super + /</code> | Open the searchable Hyprland command palette |

#### Workspaces and gestures

| Binding or gesture | Action |
|---|---|
| <code>Super + 1..9/0</code> | Focus workspace 1..9/10 |
| <code>Super + Shift + 1..9/0</code> | Move the window to a workspace and follow it |
| <code>Super + Ctrl + Down</code> | Focus an empty workspace |
| <code>Super + Ctrl + Left/Right</code> | Focus the previous/next relative workspace |
| <code>Super + Alt + Ctrl + Left/Right</code> | Move the window to a relative workspace and follow |
| <code>Super + external mouse wheel</code> | Move across existing workspaces; excluded for trackpads |
| <code>Super + S</code> | Toggle special workspace S |
| <code>Super + Shift + S</code> | Move to S and follow |
| <code>Super + Alt + S</code> | Move silently to S |
| Three-finger horizontal swipe | Move one workspace at a time |
| Four-finger swipe | Drag the active window |
| Four-finger pinch in / out | Unset maximized / toggle maximized |

#### Capture

| Binding | Action |
|---|---|
| <code>Super + Shift + P</code> | Pick and copy a color |
| <code>Super + P</code> | Capture a region |
| <code>Super + Ctrl + P</code> | Freeze, then capture a region |
| <code>Super + Alt + P</code> | Capture the focused output |
| <code>Print</code> | Capture all outputs |

Screenshots are stored in the <code>Screenshots</code> directory under the XDG pictures directory and opened in Satty.

Volume up, volume down, mute, and brightness keys remain available while locked. Volume and brightness change in 5% steps and repeat while held.

### niri key bindings

#### Windows, directional actions, and monitors

| Binding | Action |
|---|---|
| <code>Super + Q</code> / <code>Alt + F4</code> | Close the focused window |
| <code>Super + W</code> | Toggle floating |
| <code>Super + Shift + V</code> | Switch focus between floating and tiling layers |
| <code>Super + Shift + F</code> / <code>Super + F11</code> | Toggle fullscreen |
| <code>Super + F</code> | Maximize the column |
| <code>Super + M</code> | Maximize the window to available edges |
| <code>Super + Backslash</code> | Toggle tabbed column display |
| <code>Super + Alt + L</code> | Lock through Noctalia |
| <code>Alt + Tab</code> | Open niri native recent-window switching |
| <code>Super + Tab</code> | Focus the previous workspace |
| <code>Super + Escape</code> | Toggle shortcut inhibition |
| <code>Super + Shift + E</code> | Exit niri |
| <code>Super + Arrow</code> | Move a floating window by 50 px; otherwise move tiled focus |
| <code>Super + H/J/K/L</code> | Move focus in a direction |
| <code>Super + Ctrl + Arrow</code> / <code>Super + Ctrl + H/J/K/L</code> | Move columns horizontally or windows vertically within a column |
| <code>Super + Shift + Arrow</code> | Resize a floating window by 50 px; otherwise focus a monitor |
| <code>Super + Shift + H/J/K/L</code> | Focus a monitor in a direction |
| <code>Super + Ctrl + Shift + Arrow</code> / <code>H/J/K/L</code> | Move the column to a monitor |

The smart directional helper first inspects the focused window. Floating move and resize operations use the window ID captured by that same query, preventing a focus change between IPC requests from targeting another window.

#### Dynamic workspaces and scrolling layout

| Binding | Action |
|---|---|
| <code>Super + 1..9/0</code> | Focus dynamic index 1..9/10 |
| <code>Super + Shift + 1..9/0</code> | Move the current column to an index |
| <code>Super + PageDown/PageUp</code> / <code>Super + U/I</code> | Focus the next/previous workspace |
| <code>Super + Ctrl + PageDown/PageUp</code> / <code>Super + Ctrl + U/I</code> | Move the column to an adjacent workspace |
| <code>Super + Shift + PageDown/PageUp</code> / <code>Super + Shift + U/I</code> | Reorder the current workspace |
| <code>Super + wheel</code> | Switch workspaces |
| <code>Super + Ctrl + wheel</code> | Move the column to an adjacent workspace |
| <code>Super + O</code> | Toggle overview |
| <code>Super + R</code> / <code>Super + Shift + R</code> | Cycle preset column widths forward/backward |
| <code>Super + Ctrl + R</code> | Reset window height |
| <code>Super + -/=</code> | Adjust column width by 10% |
| <code>Super + Shift + -/=</code> | Adjust window height by 10% |
| <code>Super + [/]</code> | Consume or expel toward the left/right |
| <code>Super + ,/.</code> | Consume the window to the right / expel the bottom window |
| <code>Super + Home/End</code> | Focus the first/last column |
| <code>Super + Ctrl + Home/End</code> | Move the column to the beginning/end |
| <code>Super + G</code> / <code>Super + Ctrl + G</code> | Center the current column / all fully visible columns |
| <code>Super + Ctrl + F</code> | Expand the column into remaining width |
| <code>Super + Shift + /</code> | Show the niri hotkey overlay |

Application and capture bindings largely match Hyprland: <code>Super + T/E/C/B</code>, <code>Super + A/V</code>, <code>Ctrl + Shift + Escape</code>, and the same <code>P</code>/<code>Print</code> capture family. niri additionally binds microphone mute, Playerctl playback controls, and media/brightness keys that remain available while locked.

### Runtime-generated configuration

- Noctalia writes <code>~/.config/niri/noctalia.kdl</code>.
- nwg-displays writes <code>~/.config/niri/monitor.kdl</code> and Hyprland monitor/workspace Lua modules.
- Home Manager creates the two writable niri include files on first activation while keeping the main <code>config.kdl</code> declarative.
- Rime Ice is synchronized as a writable copy so Fcitx5 can generate compiled artifacts.
- Linux QQ clipboard synchronization runs as a systemd user service in the graphical session.
- At runtime, sops-nix derives an Age key from the host SSH Ed25519 key. <code>.sops.yaml</code> declares GPG and Age recipients for <code>secrets/*.yaml</code>, but no concrete secret file exists yet.
- <code>/var/lib/sbctl</code> stores this machine's Secure Boot private keys. Keep a safe offline backup, but never commit them to the repository.

### License

MIT
