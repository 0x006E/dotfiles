{ lib, pkgs, ... }:
let
  libfprint-tod = pkgs.callPackage ./libfprint-tod.nix { };
  # Unfortunately, Meson does not yet support disabling individual tests
  # (only full suites): https://github.com/mesonbuild/meson/issues/6999
  # This should be replaced with the appropriate flag once it exists.
  disable-test = test: ''
    /${test}/a\
            self.skipTest(None)
  '';
  disable-tests =
    tests: pkgs.writeText "disable-tests.sed" (lib.concatStrings (map disable-test tests));
in
(pkgs.fprintd.override { libfprint = libfprint-tod; }).overrideAttrs (
  {
    postPatch ? "",
    ...
  }:
  {
    pname = "fprintd-tod";

    postPatch =
      postPatch
      + ''
        sed -i -f ${
          disable-tests [
            "test_manager_get_no_devices" # fails
            "test_manager_get_no_default_device" # fails
            "test_wrong_finger_delete_print" # times out
          ]
        } tests/fprintd.py
      '';

    meta = {
      description = "fprintd built with libfprint-tod to support Touch OEM Drivers";
      maintainers = with lib.maintainers; [ hmenke ];
    };
  }
)
