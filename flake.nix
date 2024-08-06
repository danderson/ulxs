{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          system = system;
          config = { allowUnfree = true; };
        };
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            bluespec
            vscode
            dfu-util
            fujprog
            git
            go_1_22
            gotools
            gtkwave
            imagemagick
            nextpnr
            openfpgaloader
            picocom
            python3
            symbiyosys
            trellis
            verilator
            xdot
            yices
            yosys
            z3
            kgraphviewer
          ];
        };
      });
}
