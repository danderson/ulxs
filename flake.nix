{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    davepkgs.url = "github:danderson/nixpkgs/openfpgaloader";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = { # for shell.nix
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { nixpkgs, davepkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          system = system;
          config = { allowUnfree = true; };
        };
        dave = davepkgs.legacyPackages.${system};
        python-nmigen = dave.python3.withPackages (ps: with ps; [
          nmigen
          nmigen-boards
          nmigen-soc
        ]);
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            bluespec
            vscode
            dfu-util
            fujprog
            git
            go
            goimports
            gtkwave
            nextpnr
            dave.openfpgaloader
            python-nmigen
            redo-apenwarr
            symbiyosys
            trellis
            verilator
            yices
            yosys
            z3
          ];
        };
      });
}
