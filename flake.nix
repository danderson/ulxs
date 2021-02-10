{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    davepkgs.url = "github:danderson/nixpkgs/nmigen-update";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = { # for shell.nix
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { nixpkgs, davepkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
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
            dfu-util
            fujprog
            git
            go
            goimports
            gtkwave
            nextpnr
            python-nmigen
            redo-apenwarr
            dave.symbiyosys
            trellis
            verilator
            yices
            yosys
            z3
          ];
        };
      });
}
