{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    lean4-nix.url = "github:lenianiva/lean4-nix";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      lean4-nix,
      flake-parts,
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      perSystem =
        { system, pkgs, ... }:
        let
          lake2nix = pkgs.callPackage lean4-nix.lake { };
        in
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            overlays = [ (lean4-nix.readToolchainFile ./lean-toolchain) ];
          };
          packages.default = lake2nix.mkPackage {
            name = "CpsatScheduler";
            src = ./.;
          };
          devShells.default = pkgs.mkShell {
            packages = with pkgs.lean; [ lean-all ];
          };
        };
    };
}
