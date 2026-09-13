{ pkgs }:
{
  # Keep software available in nixpkgs on nixpkgs; list only missing packages here.
  obs-bilibili-stream = pkgs.callPackage ./obs-bilibili-stream.nix { };
  audiomonitor = pkgs.callPackage ./audiomonitor.nix { };
  bili-danmaku-tui = pkgs.callPackage ./bili-danmaku-tui.nix { };
}
