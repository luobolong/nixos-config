{ lib, ... }:
{
  programs.noctalia.settings.theme.templates = {
    enable_builtin_templates = lib.mkDefault true;
    # Desktop and application palettes share Noctalia's current theme.
    # Select only installed applications and compositors; GUI overrides win.
    builtin_ids = lib.mkDefault [
      "hyprland"
      "niri"
      "mango"
      "gtk3"
      "gtk4"
      "kitty"
      "qt"
      "kcolorscheme"
      "btop"
    ];
  };
}
