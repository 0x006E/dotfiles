{
  description = "Throwaway VM for testing desktop.guest-desktop against the real module";

  # A separate flake on purpose: the production flake's outputs (and therefore
  # `nh os switch` and CI) must not gain a second host.
  #
  # Pinned to the production flake's nixpkgs (same rev as its nixpkgs_4), so the
  # VM exercises the packages the laptop actually gets.
  inputs.nixpkgs.url = "github:nixos/nixpkgs/f9bce96a417afbb9c64725f8727e42efafeafc21";

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # A module file in this repo is a function of { delib, inputs, config,
      # lib, pkgs } returning { name, options, nixos.always, nixos.ifEnabled }.
      # This is the whole of denix's plumbing reduced to what one file needs, so
      # the VM exercises the real module rather than a copy of it; the real denix
      # wiring is covered by the production configuration evaluating.
      #
      # No mkIf or mkMerge here on purpose: this nixpkgs' module system accepts
      # neither as a bare module (denix only gets away with it because it puts
      # them under the freeform `nixos` option). The test enables the module by
      # construction, so it needs no gate.
      adapt =
        file:
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          delib = {
            module = x: x;
            singleEnableOption = true;
          };
          m = import file {
            inherit
              config
              lib
              pkgs
              delib
              ;
            inputs = { };
          };
        in
        {
          imports = [
            m.nixos.always
            (m.nixos.ifEnabled {
              name = m.name;
              cfg = {
                enable = true;
              };
              myconfig = { };
              parent = { };
            })

            # The module reads the owner's name from myconfig.constants.username
            # as an option default. denix declares that option itself via
            # `myconfigName`; this stub is the test's stand-in for it, and it is
            # the one thing the adapt shim has to supply by hand.
            {
              options.myconfig.constants.username = lib.mkOption {
                type = lib.types.str;
                default = "nithin";
              };
            }
          ];
        };
    in
    {
      nixosConfigurations.testvm = import (nixpkgs + "/nixos/lib/eval-config.nix") {
        inherit system;
        specialArgs = { inherit system; };
        modules = [
          # qemu-vm.nix provides system.build.vm: disk image, kernel, initrd and
          # cmdline. vm-up.sh boots those artefacts with the host's own qemu.
          "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
          ./vm.nix
          (adapt ../../modules/desktop/guest-desktop/default.nix)
        ];
      };

      packages.${system} = {
        default = self.nixosConfigurations.testvm.config.system.build.vm;
      };
    };
}
