{ inputs, pkgs }:
{
  # Packages absent from nixpkgs: use the project's flake before local packaging.
  audiomonitor =
    pkgs.audiomonitor
      or (inputs.audiomonitor.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
        (oldAttrs: {
          # Upstream still calls a removed icon generator; install its shipped icon.
          postInstall =
            builtins.replaceStrings
              [ ''bash "$packageSource/packaging/create-icon.sh" $out/share/icons/hicolor/256x256/apps'' ]
              [
                ''install -Dm644 "$packageSource/resources/icons/appicon_256.png" "$out/share/icons/hicolor/256x256/apps/audiomonitor.png"''
              ]
              oldAttrs.postInstall;
        })
      );
  bili-danmaku-tui =
    pkgs.bili-danmaku-tui
      or inputs.bili-danmaku-tui.packages.${pkgs.stdenv.hostPlatform.system}.default;
}
