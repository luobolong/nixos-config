{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  wrapGAppsHook3,
  glib-networking,
  gtk3,
  libayatana-appindicator,
  libsoup_3,
  webkitgtk_4_1,
}:
let
  sources = {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-NOdhI5dCJSIree6fGdXib3v38GXgwLGW0Hzpl5aKKj0=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-Uj8EewDHR8AxBWbP9qEjbSJ7ifv7ARb36eMKfcyFJOI=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation (finalAttrs: {
  pname = "antigravity-manager";
  version = "5.0.3";

  src = fetchurl {
    url = "https://github.com/lbjlaq/Antigravity-Manager/releases/download/v${finalAttrs.version}/Antigravity.Tools_${finalAttrs.version}_${source.arch}.deb";
    inherit (source) hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    wrapGAppsHook3
  ];
  buildInputs = [
    glib-networking
    gtk3
    libsoup_3
    webkitgtk_4_1
    stdenv.cc.cc.lib
  ];
  # The tray library is loaded with dlopen(), so autoPatchelf cannot detect it.
  runtimeDependencies = [ (lib.getLib libayatana-appindicator) ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r usr/bin usr/share "$out/"
    substituteInPlace "$out/share/applications/Antigravity Tools.desktop" \
      --replace-fail "Categories=" "Categories=Development;Utility;"
    runHook postInstall
  '';

  meta = {
    description = "Account manager and API proxy for Antigravity";
    homepage = "https://github.com/lbjlaq/Antigravity-Manager";
    changelog = "https://github.com/lbjlaq/Antigravity-Manager/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.cc-by-nc-sa-40;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames sources;
    mainProgram = "antigravity-tools";
  };
})
