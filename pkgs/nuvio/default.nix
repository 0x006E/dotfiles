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
  glib-networking,
  cairo,
  wrapGAppsHook3,
  autoPatchelfHook,
  nix-update,
  writeShellScript,
}:
let
  # Listed once, used three times: buildInputs, LD_LIBRARY_PATH, GST plugin
  # path. (Last two reach the player bridge, which materializes from jars at
  # runtime where autoPatchelf can't see it.)
  runtimeLibs = [
    mpv
    webkitgtk_4_1
    gtk3
    glib
    glib-networking
    fontconfig
    libX11
    libXcomposite
    libXext
    alsa-lib
    cairo
    stdenv.cc.cc.lib
  ];
  gstPlugins = with gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
  ];
in
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
    # Upstream's public backend identifiers: the anon key is public by design
    # and ships in every official release (values below recovered byte-exact
    # from the official 0.1.23-alpha AppImage; same set as the nixpkgs
    # submission, pending upstream blessing in NuvioMedia/NuvioDesktop#623).
    # Without these the client points at https://localhost and sign-in fails.
    # Trakt secret + Sentry DSNs are deliberately never baked in.
    cat >> local.properties <<EOF
    NUVIO_SUPABASE_URL=https://api.nuvio.tv
    NUVIO_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzgxNTIxMzQ2LCJleHAiOjE5MzkyMDEzNDZ9.tmQaj682pwzehpqlgCDMnySOqiUvpgRbrE43T4VJpDI
    NUVIO_SUPABASE_FALLBACK_URL=https://api-two.nuvioapp.space
    EOF
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
    wrapGAppsHook3
  ];

  buildInputs = [
    # libGL stays explicit: the Compose renderer needs it in RUNPATH, but
    # it must not precede /run/opengl-driver/lib in LD_LIBRARY_PATH.
    libGL
  ]
  ++ runtimeLibs
  ++ gstPlugins;

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
    ln -s $out/bin/Nuvio $out/bin/nuvio
    # The GApps wrapper renames the launcher to .Nuvio-wrapped, and the
    # jpackage launcher derives its .cfg name from its own file name —
    # link it back (same trick as the nixpkgs nuvio submission).
    ln -s $out/lib/app/Nuvio.cfg $out/lib/app/.Nuvio-wrapped.cfg

    mkdir -p $out/share/applications
    install -Dm444 $out/lib/Nuvio.png \
      $out/share/icons/hicolor/512x512/apps/Nuvio.png
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

  # Player libraries unpack from jars at runtime, so only the wrapper env
  # reaches them. Host NVIDIA libs for NVDEC come via /run/opengl-driver/lib.
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}:/run/opengl-driver/lib"
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${lib.makeSearchPath "lib/gstreamer-1.0" gstPlugins}"
    )
  '';

  passthru.updateScript = writeShellScript "update-nuvio" ''
    ${lib.getExe nix-update} nuvio
    echo "Now refresh the Gradle lockfile (networked, slow):"
    echo "  nix build .#nuvio.mitmCache.updateScript --print-out-paths --no-link"
  '';

  meta = with lib; {
    description = "Desktop media client for browsing and playing media (alpha, built from source)";
    homepage = "https://nuvio.tv";
    changelog = "https://github.com/NuvioMedia/NuvioDesktop/releases/tag/${finalAttrs.version}";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    mainProgram = "nuvio";
    sourceProvenance = with sourceTypes; [
      fromSource
      binaryNativeCode
    ];
  };
})
