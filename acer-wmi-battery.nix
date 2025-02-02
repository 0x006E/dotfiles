{
  stdenv,
  lib,
  fetchFromGitHub,
  kernel,
}:
stdenv.mkDerivation rec {
  name = "acer-wmi-battery-${version}-${kernel.version}";
  version = "unstable-2023-06-12";

  src = fetchFromGitHub {
    owner = "frederik-h";
    repo = "acer-wmi-battery";
    rev = "4e605fb2c78412e0c431a06e9f8ee17c9e0e0095";
    sha256 = "0b8h4qgqdgmzmzb2hvsh4psn3d432klxdfkjsarpa89iylr4irfs";
  };

  hardeningDisable = [
    "pic"
    "format"
  ]; # 1

  nativeBuildInputs = kernel.moduleBuildDependencies; # 2
  patches = [ ./patches/00_nixos.patch ];

  makeFlags = [
    "KERNELRELEASE=${kernel.modDirVersion}" # 3
    "KERNEL_DIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" # 4
    "INSTALL_MOD_PATH=$(out)" # 5
  ];

  meta = with lib; {
    description = "A linux kernel driver for the Acer WMI battery health control interface";
    homepage = "https://github.com/frederik-h/acer-wmi-battery";
    license = licenses.gpl2;
    # maintainers = [maintainers.makefu];
    platforms = platforms.linux;
  };
}
