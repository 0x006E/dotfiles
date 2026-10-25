{
  pkgs,
  lib,
  kernel,
}:
pkgs.stdenv.mkDerivation {
  pname = "uvcvideo-kernel-module";
  inherit (kernel)
    src
    version
    postPatch
    nativeBuildInputs
    ;

  kernel_dev = kernel.dev;
  kernelVersion = kernel.modDirVersion;

  modulePath = "drivers/media/usb/uvc";
  patches = kernel.patches ++ [ ./patches/00uvc_version_fix.patch ];

  # Carry the kernel's make flags, notably `cmd_sign`, so
  # `modules_install` signs the module with kmodigest and emits the
  # `<module>.ko.cer` that nixpkgs' modules aggregator concatenates into
  # `modules.cer`. Without it the out-of-tree module is unsigned and has
  # no certificate.
  makeFlags = kernel.commonMakeFlags;

  buildPhase = ''
    BUILT_KERNEL=$kernel_dev/lib/modules/$kernelVersion/build

    cp $BUILT_KERNEL/Module.symvers .
    cp $BUILT_KERNEL/.config        .
    cp $kernel_dev/vmlinux          .

    make "-j$NIX_BUILD_CORES" $makeFlags modules_prepare
    make "-j$NIX_BUILD_CORES" $makeFlags M=$modulePath modules
  '';

  installPhase = ''
    make $makeFlags \
      INSTALL_MOD_PATH="$out" \
      XZ="xz -T$NIX_BUILD_CORES" \
      M="$modulePath" \
      modules_install
  '';

  meta = {
    description = "UVC Webcam kernel module";
    license = lib.licenses.gpl3;
  };
}
