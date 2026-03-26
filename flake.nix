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
          bootstrapInstaller = pkgs.writeShellApplication {
            name = "bootstrap";
            runtimeInputs = with pkgs; [
              bash
              bitwarden-cli
              coreutils
              cryptsetup
              dosfstools
              e2fsprogs
              git
              gnugrep
              gnused
              jq
              openssh
              parted
              util-linux
            ];
            text = builtins.readFile ./scripts/bootstrap.sh;
          };
        in {
          default = {
            type = "app";
            program = "${bootstrapInstaller}/bin/bootstrap";
          };

          install = {
            type = "app";
            program = "${bootstrapInstaller}/bin/bootstrap";
          };
        });
    };
}
