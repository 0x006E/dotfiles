{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  cups,
  qtbase,
  qttools,
  wrapQtAppsHook,
  pkg-config,
  poppler,
}:
stdenv.mkDerivation rec {
  pname = "boomaga";
  version = "3.0.0-unstable-2022-02-20"; # Update this to the correct version

  src = fetchFromGitHub {
    owner = "Boomaga";
    repo = "boomaga";
    rev = "7f7ad4754b20a1027c5095b660c5229353b64c8d";
    sha256 = "1mbi66nym7s90x8zhb0dlx3wvrh7by54zs1xfafbmavg9934sdx4"; # Update with correct hash
  };

  nativeBuildInputs = [
    cmake
    wrapQtAppsHook
    pkg-config
  ];

  buildInputs = [
    cups.dev
    qtbase
    qttools
    poppler
  ];

  cmakeFlags = [
    "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
    "-DCUPS_PPD_DIR=${placeholder "out"}/share/cups/model/boomaga"
    "-DCUPS_BACKEND_DIR=${placeholder "out"}/lib/cups/backend"
  ];

  postPatch = ''
    substituteInPlace src/backend/cups_backend/main.cpp \
        --replace "if (chown(dir.c_str(), pwd->pw_uid, -1) != 0)" "if ((chown(dir.c_str(), pwd->pw_uid, -1) != 0) && (errno != EPERM))"
  '';

  meta = with lib; {
    description = "Virtual printer for viewing and editing before printing";
    homepage = "https://www.boomaga.org/";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ ]; # Add your name if you're maintaining this package
    platforms = platforms.linux;
  };
}
