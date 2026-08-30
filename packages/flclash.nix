{
  appimageTools,
  autoPatchelfHook,
  coreutils,
  fetchurl,
  gtk3,
  keybinder3,
  lib,
  libayatana-appindicator,
  libepoxy,
  makeDesktopItem,
  makeWrapper,
  stdenv,
  wrapGAppsHook3,
  writeShellScript,
  writeShellScriptBin,
}:
let
  pname = "flclash";
  version = "0.8.96";
  src = fetchurl {
    url = "https://github.com/chen08209/FlClash/releases/download/v${version}/FlClash-${version}-linux-amd64.AppImage";
    sha256 = "7a874aac6ce7608d268d25a94690b995c6c06ddd1c66851678c821c8052d3cee";
  };
  coreLauncher = writeShellScript "flclash-core-launcher" ''
    if [[ -x /run/wrappers/bin/FlClashCore ]]; then
      exec /run/wrappers/bin/FlClashCore "$@"
    fi

    exec "$(dirname -- "$0")/FlClashCore.unwrapped" "$@"
  '';
  # FlClash only recognizes a root-owned setuid core as authorized for TUN.
  # NixOS instead grants the core only CAP_NET_ADMIN through security.wrappers,
  # so make that narrow authorization look equivalent to FlClash's stat check.
  # The shim is private to the FlClash process and delegates every other call.
  statShim = writeShellScriptBin "stat" ''
    if [[ "$#" -eq 3 && "$1" == "-c" && "$2" == "%U:%G %A" && "''${3##*/}" == "FlClashCore" ]]; then
      echo "root:root -rwsr-xr-x"
      exit 0
    fi

    exec ${coreutils}/bin/stat "$@"
  '';
  contents = appimageTools.extract {
    inherit pname version src;
  };
  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "FlClash";
    comment = "A multi-platform proxy client based on ClashMeta";
    exec = pname;
    terminal = false;
    categories = [ "Network" ];
  };
in
stdenv.mkDerivation {
  inherit pname version;

  dontUnpack = true;
  dontWrapGApps = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    gtk3
    keybinder3
    libayatana-appindicator
    libepoxy
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec/flclash" "$out/share/applications"
    cp -r ${contents}/. "$out/libexec/flclash/"
    chmod -R u+w "$out/libexec/flclash"

    mv "$out/libexec/flclash/FlClashCore" "$out/libexec/flclash/FlClashCore.unwrapped"
    ln -s ${coreLauncher} "$out/libexec/flclash/FlClashCore"

    cp ${desktopItem}/share/applications/${pname}.desktop $out/share/applications/

    runHook postInstall
  '';

  preFixup = ''
    addAutoPatchelfSearchPath "$out/libexec/flclash/lib"
    addAutoPatchelfSearchPath "$out/libexec/flclash/usr/lib"
    makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';

  postFixup = ''
    makeWrapper "$out/libexec/flclash/FlClash" "$out/bin/flclash" \
      --chdir "$out/libexec/flclash" \
      --prefix PATH : "${statShim}/bin" \
      --prefix LD_LIBRARY_PATH : "$out/libexec/flclash/lib:$out/libexec/flclash/usr/lib" \
      ''${makeWrapperArgs[@]}
  '';

  meta = {
    description = "A multi-platform proxy client based on ClashMeta";
    homepage = "https://github.com/chen08209/FlClash";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
