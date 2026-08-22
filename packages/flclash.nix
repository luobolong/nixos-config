{
  appimageTools,
  fetchurl,
  lib,
  makeDesktopItem,
}:
let
  pname = "flclash";
  version = "0.8.96";
  src = fetchurl {
    url = "https://github.com/chen08209/FlClash/releases/download/v${version}/FlClash-${version}-linux-amd64.AppImage";
    sha256 = "7a874aac6ce7608d268d25a94690b995c6c06ddd1c66851678c821c8052d3cee";
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
appimageTools.wrapType2 {
  inherit pname version src;
  extraPkgs = pkgs: [ pkgs.libepoxy ];
  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cp ${desktopItem}/share/applications/${pname}.desktop $out/share/applications/
  '';
  meta = {
    description = "A multi-platform proxy client based on ClashMeta";
    homepage = "https://github.com/chen08209/FlClash";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
