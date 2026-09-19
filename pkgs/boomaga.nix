{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  cups,
  poppler,
  zlib,
  qtbase,
  qttools,
  wrapQtAppsHook,
}:
stdenv.mkDerivation rec {
  pname = "boomaga";
  version = "3.5.0";

  src = fetchFromGitHub {
    owner = "Boomaga";
    repo = "boomaga";
    rev = "v${version}";
    hash = "sha256-d+Tx2npBiDx9qGM4gBcPump/10i7JQoPFylxnmcmWoU=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    qttools
    wrapQtAppsHook
  ];

  buildInputs = [
    cups.dev
    poppler
    zlib
    qtbase
  ];

  cmakeFlags = [
    "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
    "-DCUPS_PPD_DIR=${placeholder "out"}/share/cups/model/boomaga"
    "-DCUPS_BACKEND_DIR=${placeholder "out"}/lib/cups/backend"
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
  ];

  # The CUPS backend is written to run as root: it chowns the spool file
  # and setuids to the job owner before execing the GUI. cupsd on NixOS
  # spawns backends as cups:lp, so don't hard-fail on EPERM here; the
  # services.boomaga module grants the backend the capabilities it needs
  # (chown/fowner/setuid/setgid) via setcap so they succeed at runtime.
  postPatch = ''
    substituteInPlace src/backend/cups_backend/main.cpp \
      --replace-fail "if (chown(dir.c_str(), pwd->pw_uid, -1) != 0)" "if ((chown(dir.c_str(), pwd->pw_uid, -1) != 0) && (errno != EPERM))" \
      --replace-fail "if (chown(destFile.c_str(), args.pwd->pw_uid, -1) != 0)" "if ((chown(destFile.c_str(), args.pwd->pw_uid, -1) != 0) && (errno != EPERM))"
  '';

  meta = with lib; {
    description = "Virtual printer for viewing and editing before printing";
    homepage = "https://github.com/Boomaga/boomaga";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
  };
}
