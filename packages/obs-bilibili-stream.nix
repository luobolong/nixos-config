{
  lib,
  stdenv,
  cmake,
  curl,
  fetchFromGitHub,
  obs-studio,
  pkg-config,
  qt6,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "obs-bilibili-stream";
  version = "2.1.5";

  src = fetchFromGitHub {
    owner = "Zarosmm";
    repo = "obs-bilibili-stream";
    tag = finalAttrs.version;
    hash = "sha256-cFIPbOHhafsH1YLV8wqnRZF+df3K/cEWP6h6KuZsqNc=";
  };

  # This package installs an OBS plugin library, not a standalone Qt app.
  dontWrapQtApps = true;

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
})
