{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    davepkgs.url = "github:danderson/nixpkgs/danderson/bluespec";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, davepkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          system = system;
          config = { allowUnfree = true; };
        };
        daveblue = import davepkgs {
          system = system;
          config = { allowUnfree = true; };
        };
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            daveblue.bluespec
            vscode
            dfu-util
            fujprog
            git
            go_1_18
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
