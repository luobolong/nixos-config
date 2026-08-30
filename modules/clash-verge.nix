{ pkgs, ... }:
{
  programs.clash-verge = {
    enable = true;
    package = pkgs.clash-verge-rev;
    autoStart = false;
    serviceMode = false;
    tunMode = true;
  };
}
