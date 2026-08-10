{ appimageTools, fetchurl, lib, makeDesktopItem }:
let
  pname = "flclash";
  version = "0.8.94";
  src = fetchurl {
    url = "https://github.com/chen08209/FlClash/releases/download/v${version}/FlClash-${version}-linux-amd64.AppImage";
    sha256 = "a022672d7fee78f89a3f83ae4f6390ddb79600790f532bfd1969995fc51c727d";
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
