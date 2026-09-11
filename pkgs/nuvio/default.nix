{
  lib,
  stdenv,
  fetchFromGitHub,
  gradle_9,
  jdk21,
  jdk17,
  cmake,
  pkg-config,
  mpv,
  webkitgtk_4_1,
  gtk3,
  gst_all_1,
  alsa-lib,
  fontconfig,
  libGL,
  libX11,
  libXext,
  libXcomposite,
  glib,
  cairo,
  autoPatchelfHook,
  nix-update,
  writeShellScript,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "nuvio";
  version = "0.1.23-alpha";

  src = fetchFromGitHub {
    owner = "NuvioMedia";
    repo = "NuvioDesktop";
    rev = "0.1.23-alpha";
    # NOTE: no fetchSubmodules — MPVKit has a branch-pinned URL and
    # libass-android is a stale gitlink with no URL at all (fetch fails);
    # neither is referenced by any desktop build file.
    hash = "sha256-dCzSotVSLQjspIodpbdZAcUuCZLmcVU4T+Sgbtt0NMA=";
  };

  patches = [
    # Temporarily smaller desktop type scale (upstream has no UI-scale setting).
    ./patches/fontscale.patch
    # Nix-managed app must not self-update (would fight the package manager).
    ./patches/no-updater.patch
  ];

  postPatch = ''
    echo "kotlin.native.ignoreDisabledTargets=true" >> local.properties
  '';

  gradleBuildTask = ":composeApp:createReleaseDistributable";
  gradleUpdateTask = finalAttrs.gradleBuildTask;

  mitmCache = gradle_9.fetchDeps {
    inherit (finalAttrs) pname;
    pkg = finalAttrs.finalPackage;
    data = ./deps.json;
    silent = false;
    useBwrap = false;
  };

  env = {
    JAVA_HOME = "${jdk21}/lib/openjdk";
    # Dummy satisfies AGP configuration without an Android SDK; no Android
    # tasks run in a desktop-only build.
    ANDROID_SDK_HOME = "$(pwd)";
  };

  gradleFlags = [
    "-Dorg.gradle.java.home=${jdk21}/lib/openjdk"
    # Vendor module pins a Java 17 toolchain: satisfy it from nixpkgs so
    # foojay never tries a network download in the sandbox.
    "-Porg.gradle.java.installations.paths=${jdk17}"
    "-Porg.gradle.java.installations.auto-download=false"
  ];

  nativeBuildInputs = [
    gradle_9
    cmake
    pkg-config
    autoPatchelfHook
  ];

  buildInputs = [
    # Bridge (player_bridge.cpp) links these at compile time via pkg-config;
    # vendor NativeVideoPlayer links GStreamer + JNI. autoPatchelf wires the
    # runtime RUNPATHs from the same set.
    mpv
    webkitgtk_4_1
    gtk3
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    fontconfig
    alsa-lib
    libGL
    libX11
    libXext
    libXcomposite
  ];

  doCheck = false;

  # cmake binary is needed by the vendor media player's build.sh, but its
  # setup hook must not auto-configure the repo root (no top-level
  # CMakeLists.txt there).
  dontUseCmakeConfigure = true;

  installPhase = ''
    runHook preInstall

    dist=composeApp/build/compose/binaries/main-release/app/Nuvio
    test -d "$dist" || {
      echo "unexpected dist layout, contents:"
      find composeApp/build/compose -maxdepth 5 | head -50
      exit 1
    }
    mkdir -p $out
    cp -r "$dist"/. $out/
    # Plain launcher script (NOT makeWrapper): the native binary derives its
    # config filename from argv[0]'s basename (lib/app/Nuvio.cfg), and
    # makeWrapper's .Nuvio-wrapped rename breaks that lookup. exec keeps
    # argv[0] ending in Nuvio however the user invoked us.
    cat > $out/bin/nuvio <<EOF
    #!${stdenv.shell}
    export LD_LIBRARY_PATH="${
      lib.makeLibraryPath [
        mpv
        webkitgtk_4_1
        gtk3
        glib
        cairo
        libX11
        libXcomposite
        stdenv.cc.cc.lib
      ]
    }:\$LD_LIBRARY_PATH"
    exec "$out/bin/Nuvio" "\$@"
    EOF
    chmod +x $out/bin/nuvio

    mkdir -p $out/share/applications
    install -Dm444 composeApp/src/desktopMain/resources/icons/nuvio-app-icon-transparent.png \
      $out/share/icons/hicolor/256x256/apps/Nuvio.png
    cat > $out/share/applications/Nuvio.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Nuvio
    Comment=Nuvio Media Player
    Exec=nuvio
    Icon=Nuvio
    Terminal=false
    Categories=AudioVideo;
    EOF

    runHook postInstall
  '';

  passthru.updateScript = writeShellScript "update-nuvio" ''
    ${lib.getExe nix-update} nuvio
    echo "Now refresh the Gradle lockfile (networked, slow):"
    echo "  nix build .#nuvio.mitmCache.updateScript --print-out-paths --no-link"
  '';

  meta = with lib; {
    description = "Desktop media client for browsing and playing media (alpha, built from source)";
    homepage = "https://nuvio.tv";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    mainProgram = "nuvio";
  };
})
