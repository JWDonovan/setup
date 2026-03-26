{
  description = "Public bootstrap for the jwdonovan NixOS installer flow";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { nixpkgs, ... }:
    let
      systems = [ "aarch64-linux" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in {
      apps = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          bootstrapVm = pkgs.writeShellApplication {
            name = "bootstrap-vm";
            runtimeInputs = with pkgs; [
              bash
              coreutils
              dosfstools
              e2fsprogs
              git
              gh
              gnugrep
              gnused
              openssh
              parted
              util-linux
            ];
            text = builtins.readFile ./scripts/bootstrap-vm.sh;
          };
        in {
          default = {
            type = "app";
            program = "${bootstrapVm}/bin/bootstrap-vm";
          };

          vm = {
            type = "app";
            program = "${bootstrapVm}/bin/bootstrap-vm";
          };
        });
    };
}
