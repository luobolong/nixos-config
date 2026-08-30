{
  buildFHSEnv,
  dpkg,
  fetchurl,
  lib,
  stdenvNoCC,
}:
let
  pname = "chatgpt";
  version = "26.825.51511";

  unwrapped = stdenvNoCC.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version;

    src = fetchurl {
      url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
      hash = "sha256-NVSwAixs+1EzJvQ/0R9xiDWncIasTXyi/z67ui1Mf0U=";
    };

    nativeBuildInputs = [ dpkg ];

    unpackPhase = ''
      runHook preUnpack
      dpkg-deb --extract "$src" .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib" "$out/share/applications" "$out/share/pixmaps"
      cp -a usr/lib/chatgpt "$out/lib/"
      cp -a usr/share/applications/chatgpt.desktop "$out/share/applications/"
      cp -a usr/share/pixmaps/chatgpt.png "$out/share/pixmaps/"

      runHook postInstall
    '';

    dontStrip = true;
  };
in
buildFHSEnv {
  inherit pname version;

  runScript = lib.concatStringsSep " " [
    "${unwrapped}/lib/chatgpt/codex-launcher"
    "--enable-features=UseOzonePlatform"
    "--ozone-platform=wayland"
    "--enable-wayland-ime"
    "--wayland-text-input-version=3"
  ];

  targetPkgs =
    pkgs:
    with pkgs;
    map lib.getLib [
      alsa-lib
      atk
      cairo
      cups
      dbus
      expat
      fontconfig
      gdk-pixbuf
      glib
      gtk3
      libdrm
      libgbm
      libglvnd
      libnotify
      libusb1
      libuuid
      libx11
      libxcb
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxkbcommon
      libxrandr
      libxrender
      libxshmfence
      libxscrnsaver
      libxtst
      nspr
      nss
      pango
      udev
      vulkan-loader
      wayland
    ]
    ++ [
      git
      xdg-utils
    ];

  extraInstallCommands = ''
    mkdir -p "$out/share/applications" "$out/share/pixmaps"
    ln -s ${unwrapped}/share/applications/chatgpt.desktop \
      "$out/share/applications/chatgpt.desktop"
    ln -s ${unwrapped}/share/pixmaps/chatgpt.png \
      "$out/share/pixmaps/chatgpt.png"
  '';

  passthru = { inherit unwrapped; };

  meta = {
    description = "Official ChatGPT desktop application for Linux";
    homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
