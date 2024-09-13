{
  stdenv,
  lib,
  fetchFromGitHub,
  kernel,
}:
stdenv.mkDerivation rec {
  name = "acer-wmi-battery-${version}-${kernel.version}";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "frederik-h";
    repo = "acer-wmi-battery";
    rev = "v${version}";
    sha256 = "2uVIMvUxIXWz0nK61ukUg7Rh9SVQbyjWr7++hh8mEC0=";
  };

  sourceRoot = "source";
  hardeningDisable = [
    "pic"
    "format"
  ]; # 1
  nativeBuildInputs = kernel.moduleBuildDependencies; # 2
  patches = [./kernel/00_nixos.patch];

  makeFlags =
    kernel.makeFlags
    ++ [
      # Variable refers to the local Makefile.
      "KERNELDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      # Variable of the Linux src tree's main Makefile.
      "INSTALL_MOD_PATH=$(out)"
    ];

  buildFlags = ["modules"];
  installTargets = ["modules_install"];

  meta = with lib; {
    description = "A linux kernel driver for the Acer WMI battery health control interface";
    homepage = "https://github.com/frederik-h/acer-wmi-battery";
    license = licenses.gpl2;
    # maintainers = [maintainers.makefu];
    platforms = platforms.linux;
  };
}
