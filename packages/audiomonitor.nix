{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  qt6,
  pipewire,
  libglvnd,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "audiomonitor";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "luobolong";
    repo = "audiomonitor";
    tag = finalAttrs.version;
    hash = "sha256-0CBazG5EJMYUBKp/Hd0su6Zbm20Yy/DvnmEjVx4nOQg=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.qttools
    qt6.wrapQtAppsHook
  ];
  buildInputs = [
    qt6.qtbase
    pipewire
    libglvnd
  ];
  cmakeFlags = [
    "-DCMAKE_INCLUDE_PATH=${lib.getDev libglvnd}/include"
    "-DCMAKE_LIBRARY_PATH=${lib.getLib libglvnd}/lib"
  ];
  doCheck = true;

  postInstall = ''
    install -Dm644 ../packaging/audiomonitor.desktop $out/share/applications/audiomonitor.desktop
    install -Dm644 ../README.md $out/share/doc/audiomonitor/README.md
    install -Dm644 ../LICENSE $out/share/licenses/audiomonitor/LICENSE
    # Use the shipped icon; the upstream generator requires extra image tools.
    install -Dm644 ../resources/icons/appicon_256.png $out/share/icons/hicolor/256x256/apps/audiomonitor.png
  '';

  meta = {
    description = "Forward audio from one output device to another in real time";
    homepage = "https://github.com/luobolong/audiomonitor";
    license = lib.licenses.mit;
    mainProgram = "audiomonitor";
    platforms = lib.platforms.linux;
  };
})
