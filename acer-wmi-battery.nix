{
  pkgs,
  stdenv,
  lib,
  fetchFromGitHub,
  kernel ? pkgs.linuxPackages_cachyos.latest,
}:
stdenv.mkDerivation rec {
  name = "acer-wmi-battery-${version}-${kernel.version}";
  version = "unstable-2025-04-24";

  src = fetchFromGitHub {
    owner = "frederik-h";
    repo = "acer-wmi-battery";
    rev = "0889d3ea54655eaa88de552b334911ce7375952f";
    sha256 = "sha256-mI6Ob9BmNfwqT3nndWf3jkz8f7tV10odkTnfApsNo+A=";
  };

  setSourceRoot = "export sourceRoot=$(pwd)/source";
  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "-C"
    "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "M=$(sourceRoot)"
  ];
  buildFlags = [ "modules" ];
  installFlags = [ "INSTALL_MOD_PATH=${placeholder "out"}" ];
  installTargets = [ "modules_install" ];

  meta = with lib; {
    description = "A linux kernel driver for the Acer WMI battery health control interface";
    homepage = "https://github.com/frederik-h/acer-wmi-battery";
    license = licenses.gpl2;
    # maintainers = [maintainers.makefu];
    platforms = platforms.linux;
  };
}
