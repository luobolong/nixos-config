#!/usr/bin/env bash
set -euo pipefail

packages_url="https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages"

latest_version="$({
  curl --fail --silent --show-error --location "$packages_url"
} | awk '
  /^Package: / { package = $2 }
  /^Version: / && package == "chatgpt" { print $2; exit }
')"

if [[ ! "$latest_version" =~ ^[0-9]+([.][0-9]+)+$ ]]; then
  printf 'Could not determine a valid ChatGPT version from %s\n' "$packages_url" >&2
  exit 1
fi

current_version="$(nix eval --raw .#chatgpt.version)"
if [[ "$current_version" == "$latest_version" ]]; then
  printf 'ChatGPT is already current: %s\n' "$current_version"
  exit 0
fi

printf 'Updating ChatGPT: %s -> %s\n' "$current_version" "$latest_version"
nix-update --flake --version "$latest_version" --build chatgpt
