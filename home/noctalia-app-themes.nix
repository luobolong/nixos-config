{
  config,
  lib,
  pkgs,
  ...
}:
let
  noctalia = config.programs.noctalia.package;
  undoHook =
    template:
    pkgs.writeShellScript "noctalia-${template}-undo" ''
      exec ${pkgs.bash}/bin/bash ${./scripts/noctalia-template-undo.sh} ${template}
    '';
  # Adapt the hooks for independent template switches and read-only main
  # configs while retaining the cached Noctalia binary.
  assets = pkgs.runCommand "noctalia-home-manager-assets" { } ''
    mkdir -p "$out"
    cp -rs ${noctalia}/share/noctalia/assets/. "$out/"
    chmod u+w "$out/templates/kitty" "$out/templates/gtk"
    ln -sfn ${./scripts/noctalia-kitty-apply.sh} "$out/templates/kitty/apply.sh"
    # Both GTK templates share this hook; the other toolkit may be disabled.
    cp --remove-destination ${noctalia}/share/noctalia/assets/templates/gtk/apply.sh \
      "$out/templates/gtk/apply.sh"
    chmod u+w "$out/templates/gtk/apply.sh"
    substituteInPlace "$out/templates/gtk/apply.sh" --replace-fail \
      'echo "Error: $label noctalia.css not found at $colors_file" >&2
            return 1' \
      'return 0'
    ${lib.concatMapStringsSep "\n"
      (template: ''
        chmod u+w "$out/templates/${template}"
        ln -sfn ${undoHook template} "$out/templates/${template}/undo.sh"
      '')
      [
        "kitty"
        "niri"
        "hyprland"
        "mango"
      ]
    }
  '';
  # Seed writable outputs before the first Noctalia run. Existing palettes are
  # preserved; subsequent changes are rendered by Noctalia itself.
  fallback = pkgs.runCommand "noctalia-app-theme-fallback" { } ''
    mkdir -p "$out/config/kitty/themes" "$out/config/qt5ct/colors" "$out/config/qt6ct/colors" \
      "$out/data/color-schemes"
    ${lib.getExe noctalia} theme --theme-json ${./templates/noctalia-fallback.json} \
      --dark --default-mode dark -o "$TMPDIR/palette.json" \
      --render '${assets}/templates/kitty/kitty.conf:'"$out/config/kitty/themes/noctalia.conf" \
      --render '${assets}/templates/qt/qtct.conf:'"$out/config/qt5ct/colors/noctalia.conf" \
      --render '${assets}/templates/kde/kcolorscheme.colors:'"$out/data/color-schemes/noctalia.colors"
    cp "$out/config/qt5ct/colors/noctalia.conf" "$out/config/qt6ct/colors/noctalia.conf"
    ${pkgs.python3}/bin/python3 - "$out" <<'PY'
    import configparser
    from pathlib import Path
    import sys
    root = Path(sys.argv[1])
    config = configparser.ConfigParser(interpolation=None)
    config.optionxform = str
    config.read(root / "data/color-schemes/noctalia.colors")
    config["General"]["TerminalApplication"] = "kitty"
    config["Icons"] = {"Theme": "Papirus-Dark"}
    config["UiSettings"] = {"ColorScheme": "noctalia"}
    config["Wallet"] = {"Enabled": "false"}
    with (root / "config/kdeglobals").open("w") as output:
        config.write(output, space_around_delimiters=False)
    PY
  '';
  setup = pkgs.writeShellApplication {
    name = "noctalia-app-theme-setup";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      seed() {
        local source="$1" target="$2"
        if [[ ! -e "$target" ]]; then
          mkdir -p "$(dirname "$target")"
          install -m 0644 "$source" "$target"
        fi
      }
      for relative in \
        kitty/themes/noctalia.conf qt5ct/colors/noctalia.conf qt6ct/colors/noctalia.conf \
        kdeglobals; do
        seed "${fallback}/config/$relative" "${config.xdg.configHome}/$relative"
      done
      seed ${fallback}/data/color-schemes/noctalia.colors \
        ${lib.escapeShellArg "${config.xdg.dataHome}/color-schemes/noctalia.colors"}
    '';
  };
in
{
  # Noctalia's native hooks manage GTK3/GTK4 CSS. Limit the base theme to GTK3.
  gtk.gtk3.theme = {
    name = "adw-gtk3-dark";
    package = pkgs.adw-gtk3;
  };
  programs.kitty.extraConfig = ''
    include themes/noctalia.conf
  '';
  systemd.user.services.noctalia.Service.Environment = [ "NOCTALIA_ASSETS_DIR=${assets}" ];
  home.activation.ensureNoctaliaAppThemes = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    $DRY_RUN_CMD ${lib.getExe setup}
  '';
}
