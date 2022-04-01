{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    davepkgs.url = "github:danderson/nixpkgs/danderson/bluespec";
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
        dave = import davepkgs {
          system = system;
          config = { allowUnfree = true; };
        };
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            dave.bluespec
            vscode
            dfu-util
            fujprog
            git
            go
            gotools
            gtkwave
            imagemagick
            nextpnr
            openfpgaloader
            picocom
            python3
            redo-apenwarr
            symbiyosys
            trellis
            verilator
            xdot
            yices
            yosys
            z3
          ];
        };
      });
}
