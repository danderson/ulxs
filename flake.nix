{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = { # for shell.nix
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            redo-apenwarr
            go
            goimports
            python3
            gtkwave
            git
            yosys
            symbiyosys
            trellis
            nextpnr
            verilator
            fujprog
            dfu-util
          ];
        };
      });
}
