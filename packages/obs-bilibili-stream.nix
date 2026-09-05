{
  lib,
  stdenv,
  cmake,
  curl,
  obs-studio,
  pkg-config,
  qt6,
  src,
}:

stdenv.mkDerivation {
  pname = "obs-bilibili-stream";
  version = "2.1.3";
  inherit src;

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    curl
    obs-studio
    qt6.qtbase
  ];

  cmakeFlags = [
    "-DENABLE_FRONTEND_API=ON"
    "-DENABLE_QT=ON"
  ];

  meta = {
    description = "Bilibili live streaming plugin for OBS Studio";
    homepage = "https://github.com/Zarosmm/obs-bilibili-stream";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
}
