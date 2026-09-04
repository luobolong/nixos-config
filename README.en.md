# NixOS-WSL Configuration

Personal NixOS and Home Manager configuration for WSL2.

[中文](README.md)

## Overview

| Item | Current value |
|---|---|
| Flake output | <code>nixosConfigurations.wsl</code> |
| Architecture | <code>x86_64-linux</code> |
| Host name | <code>wsl</code> |
| User name | <code>nixos</code> |
| Nixpkgs | <code>nixos-unstable</code> |
| State version | <code>25.11</code> |
| Graphics | WSLg |

This branch configures only the WSL userspace. Windows and WSL manage system startup, the Linux kernel, virtual storage, networking, and the graphics bridge.

Highlights:

- NixOS-WSL and Home Manager.
- Zsh, Starship, fzf, zoxide, eza, bat, and common development tools.
- Wayland, X11, GTK, Qt/KDE, and Electron application support through WSLg.
- Fcitx5 with Rime Ice for Chinese input.
- Catppuccin, Papirus, Inter, Noto CJK/Emoji, and Nerd Fonts.
- Hyprland and niri configuration files remain available for manual testing or reuse, but WSL does not start a nested desktop session by default.

## Apply the configuration

~~~bash
git clone https://github.com/luobolong/nixos-config.git
cd nixos-config
git switch wsl
sudo nixos-rebuild switch --flake .#wsl
~~~

Apply later updates with:

~~~bash
git pull
sudo nixos-rebuild switch --flake .#wsl
~~~

Validate without switching:

~~~bash
nix flake check --no-build
nix build .#nixosConfigurations.wsl.config.system.build.toplevel --no-link
~~~

A dirty Git tree warning only means that the repository contains uncommitted changes; it does not cause a build failure by itself. Stage or commit newly added Flake source files before the final validation so Nix can see them.

## Review before first use

The host and user names are defined in <code>flake.nix</code>:

~~~nix
let
  system = "x86_64-linux";
  hostname = "wsl";
  username = "nixos";
in
~~~

Use the new host name as the rebuild target after changing it.

<code>modules/wsl.nix</code> currently contains the placeholder hash for the weak password <code>q</code>, and <code>users.mutableUsers = false</code>. Generate and replace the password hash before regular use:

~~~bash
nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512
~~~

Also review the Git name, email, signing key, and other personal values in <code>home/default.nix</code>.

## WSLg and displays

- WSLg provides the Wayland and X11 connections, so Linux GUI applications can start directly from a terminal.
- The WSL overrides disable automatic startup of Hyprland, Noctalia, and their user services.
- Hyprland uses a generic fallback display scale of <code>1</code>.
- niri does not declare fixed output names, modes, positions, or scales; WSLg determines the display output.
- Home Manager creates niri's writable <code>noctalia.kdl</code> include during activation.

## Repository layout

~~~text
.
├── flake.nix                         # WSL inputs and nixosConfigurations.wsl
├── flake.lock
├── hosts/wsl/default.nix             # NixOS-WSL and Home Manager wiring
├── modules/wsl.nix                   # WSL system userspace configuration
├── home/
│   ├── default.nix                   # Applications, theme, environment, services
│   ├── wsl.nix                       # WSL-specific overrides
│   ├── zsh.nix                       # Shell configuration
│   ├── hyprland.lua                  # Hyprland configuration
│   ├── niri.kdl                      # niri configuration
│   └── niri-smart-direction.sh
└── packages/
    ├── chatgpt.nix
    └── deepseek-harness.nix
~~~

## Desktop and development environment

Desktop applications include Firefox, Spotify, LocalSend, OBS Studio, Mission Center, Pavucontrol, AudioMonitor, ChatGPT, Dolphin, Okular, Gwenview, Ark, mpv, and VS Code.

Development tools include GCC, CMake, Make, pkg-config, Node.js, Python, OpenJDK, Lua language server, nil, nixfmt, ShellCheck, Codex, DeepSeek Harness, sops, nh, nvd, and nix-output-monitor.

Default applications:

- Kitty for terminals
- Dolphin for directories
- Firefox for the web
- VS Code for text
- Okular for PDF files
- Gwenview for images
- mpv for audio and video
- Ark for archives

## Maintenance

~~~bash
# Update the lock file
nix flake update

# Validate the configuration
nix flake check --no-build

# Apply the configuration
sudo nixos-rebuild switch --flake .#wsl

# Inspect failed user services
systemctl --user --failed
~~~

The system configuration removes Nix store generations older than seven days and optimizes the store weekly. Use <code>wsl --export</code> for WSL backups, and separately back up uncommitted configuration, project files, and credentials.

## License

MIT
