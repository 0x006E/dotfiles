{ lib
, stdenv
, fetchFromGitHub
, cmake
, cups
, qtbase
, qttools
, wrapQtAppsHook
, pkg-config
, poppler
}:

stdenv.mkDerivation rec {
  pname = "boomaga";
  version = "3.0.0"; # Update this to the correct version

  src = fetchFromGitHub {
    owner = "Boomaga";
    repo = "boomaga";
    rev = "v${version}";
    sha256 = "sha256-ThiyZ/fTwp+E639HavUv9WbRE+RxGbRwcPqXSuVWdaQ="; # Update with correct hash
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
    "-DCUPS_PPD_DIR=${placeholder "out"}/share/ppd/boomaga"
    "-DCUPS_BACKEND_DIR=${placeholder "out"}/lib/cups" 
  ];


  meta = with lib; {
    description = "Virtual printer for viewing and editing before printing";
    homepage = "https://www.boomaga.org/";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ ]; # Add your name if you're maintaining this package
    platforms = platforms.linux;
  };
}
