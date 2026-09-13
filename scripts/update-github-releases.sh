#!/usr/bin/env bash
set -euo pipefail

# Run from the configuration checkout. nix-update handles release discovery and hashes.
for package in obs-bilibili-stream audiomonitor bili-danmaku-tui; do
  nix-update --flake --use-github-releases --version=stable --build "$package"
done

printf 'GitHub Release packages updated and built. Apply with: sudo nixos-rebuild switch --flake .#nixos\n'
