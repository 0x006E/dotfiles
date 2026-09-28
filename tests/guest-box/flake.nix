{
  description = "Throwaway VM for testing services.guest-box against the real module";

  # A separate flake on purpose: the production flake's outputs (and therefore
  # `nh os switch` and CI) must not gain a second host.
  #
  # Pinned to the production flake's nixpkgs: the test must build the same
  # packages the laptop does, not whatever unstable happens to be today.
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
      # This is the whole of denix's plumbing, reduced to what one file needs, so
      # the VM exercises the real module rather than a copy of it; the real denix
      # wiring is covered by the production configuration evaluating.
      #
      # No mkIf or mkMerge here on purpose: this nixpkgs' module system accepts
      # neither as a bare module (denix only gets away with it because it puts
      # them under the freeform `nixos` option). The test enables the module by
      # construction, so it needs no gate -- importing the two plain modules is
      # the whole job.
      #
      # `inputs` is the module's flake inputs in the real build; the VM
      # substitutes nixpkgs' xwayland-satellite for the niri flake's.
      testInputs = {
        niri.packages.${system}.xwayland-satellite-unstable = pkgs.xwayland-satellite;
      };

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
            inputs = testInputs;
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
          ];
        };
    in
    {
      nixosConfigurations.testvm = import (nixpkgs + "/nixos/lib/eval-config.nix") {
        inherit system;
        specialArgs = { inherit system; };
        modules = [
          # qemu-vm.nix provides system.build.vm: disk image, kernel, initrd and
          # cmdline. vm-up.sh boots those artefacts with the host's own qemu,
          # with the serial console on a file and the screen on VNC.
          "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
          ./vm.nix
          (adapt ../../modules/services/guest-box/default.nix)
        ];
      };

      packages.${system} = {
        default = self.nixosConfigurations.testvm.config.system.build.vm;
      };
    };
}
