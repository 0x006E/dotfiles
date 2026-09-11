{
  pkgs,
  lib,
  kernel,
}:
pkgs.stdenv.mkDerivation {
  pname = "alc269-kernel-module";
  inherit (kernel)
    src
    version
    postPatch
    nativeBuildInputs
    ;

  kernel_dev = kernel.dev;
  kernelVersion = kernel.modDirVersion;

  modulePath = "sound/hda/codecs/realtek";
  patches = kernel.patches ++ [ ./patches/00acer-quirk.patch ];

  buildPhase = ''
    BUILT_KERNEL=$kernel_dev/lib/modules/$kernelVersion/build

    cp $BUILT_KERNEL/Module.symvers .
    cp $BUILT_KERNEL/.config        .
    cp $kernel_dev/vmlinux          .

    make "-j$NIX_BUILD_CORES" modules_prepare
    make "-j$NIX_BUILD_CORES" M=$modulePath modules
  '';

  # Install only snd-hda-codec-alc269.ko: the directory also builds ten
  # unmodified twins of in-tree modules, which would wastefully shadow
  # the originals. (Only alc269.c carries the quirk.)
  # Like uvcvideo: modules_install handles stripping, compression and
  # depmod metadata. Then drop everything except our patched module --
  # the directory also builds ten unmodified twins of in-tree modules
  # that would wastefully shadow the originals. (Only alc269.c carries
  # the quirk.)
  installPhase = ''
    make \
      INSTALL_MOD_PATH="$out" \
      XZ="xz -T$NIX_BUILD_CORES" \
      M="$modulePath" \
      modules_install
    find "$out" -name 'snd-hda-codec-*.ko*' ! -name 'snd-hda-codec-alc269.ko*' -delete
  '';

  meta = {
    description = "Out-of-tree snd-hda-codec-alc269 with Acer Aspire A515-57G headset-mic quirk";
    license = lib.licenses.gpl2Only;
  };
}
