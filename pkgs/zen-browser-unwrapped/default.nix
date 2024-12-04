{
  lib,
  stdenv,
  fetchurl,
  config,
  wrapGAppsHook3,
  autoPatchelfHook,
  alsa-lib,
  curl,
  dbus-glib,
  gtk3,
  libXtst,
  libva,
  pciutils,
  pipewire,
  adwaita-icon-theme,
  writeText,
  patchelfUnstable, # have to use patchelfUnstable to support --no-clobber-old-sections
}:

let

  mozillaPlatforms = {
    "i686-linux" = "linux-i686";
    "x86_64-linux" = "linux-x86_64";
  };

  policies = {
    DisableAppUpdate = true;
  } // config.firefox.policies or { };

  policiesJson = writeText "firefox-policies.json" (builtins.toJSON { inherit policies; });

in
stdenv.mkDerivation rec {
  pname = "zen-browser-unwrapped";
  version = "twilight";

  src = fetchurl {
    url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-specific.tar.bz2";
    hash = "sha256-cuFJI4PgdFlEn++hcm7HQt+NS1D9PTinRs1X4HF0emM=";

  };

  nativeBuildInputs = [
    wrapGAppsHook3
    autoPatchelfHook
    patchelfUnstable
  ];
  buildInputs = [
    gtk3
    adwaita-icon-theme
    alsa-lib
    dbus-glib
    libXtst
  ];
  runtimeDependencies = [
    curl
    libva.out
    pciutils
  ];
  appendRunpaths = [
    "${pipewire}/lib"
  ];
  # zen uses "relrhack" to manually process relocations from a fixed offset
  patchelfFlags = [ "--no-clobber-old-sections" ];

  installPhase = ''
    mkdir -p "$prefix/lib/zen-bin-${version}"
    cp -r * "$prefix/lib/zen-bin-${version}"

    mkdir -p "$out/bin"
    ln -s "$prefix/lib/zen-bin-${version}/zen" "$out/bin/zen"

    # See: https://github.com/mozilla/policy-templates/blob/master/README.md
    mkdir -p "$out/lib/zen-bin-${version}/distribution";


    ln -s ${policiesJson} "$out/lib/zen-bin-${version}/distribution/policies.json";
    install -D browser/chrome/icons/default/default16.png $out/share/icons/hicolor/16x16/apps/zen.png
    install -D browser/chrome/icons/default/default32.png $out/share/icons/hicolor/32x32/apps/zen.png
    install -D browser/chrome/icons/default/default48.png $out/share/icons/hicolor/48x48/apps/zen.png
    install -D browser/chrome/icons/default/default64.png $out/share/icons/hicolor/64x64/apps/zen.png
    install -D browser/chrome/icons/default/default128.png $out/share/icons/hicolor/128x128/apps/zen.png
  '';

  meta = {
    mainProgram = "zen";
    description = "Firefox based browser with a focus on privacy and customization (binary package)";
    homepage = "https://www.zen-browser.app/";
    license = lib.licenses.mpl20;
    maintainers = [ ];
    platforms = builtins.attrNames mozillaPlatforms;
  };

  passthru = {
    updateScript = ./update.sh;

    # These values are used by `wrapFirefox`.
    # ref; `pkgs/applications/networking/browsers/zen/wrapper.nix'
    binaryName = meta.mainProgram;
    execdir = "/bin";
    libName = "zen-bin-${version}";
    ffmpegSupport = true;
    gssSupport = true;
    gtk3 = gtk3;
  };
}
