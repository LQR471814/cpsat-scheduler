{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nu-type-alias-pkg.url = "git+https://github.com/LQR471814/nu-type-alias";
    nu-type-alias-pkg.url = "path:/home/lqr471814/go/src/nu-type-alias";
  };
  outputs =
    {
      self,
      nixpkgs,

      nu-type-alias-pkg,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
    in
    {
      devShells.${system}.default =
        let
          libs = with pkgs; [ ];
          protoc-gen-nu = pkgs.writeShellScriptBin "protoc-gen-nu" ''
            project_root="$(git rev-parse --show-toplevel)"
            go run ''${project_root}/cmd/gen/protoc-gen-nu
          '';
          nu-type-alias = nu-type-alias-pkg.packages.${system}.default;
        in
        pkgs.mkShell {
          name = "devenv";
          buildInputs = libs;
          nativeBuildInputs = (
            with pkgs;
            [
              go
              pkg-config
              sqlc

              protobuf
              protoc-gen-go
              protoc-gen-go-grpc
              python313Packages.grpcio-tools
              buf
              protoc-gen-nu

              (nu-type-alias.overrideAttrs (old: {
                doCheck = false;
              }))
            ]
          );

          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath libs}:$LD_LIBRARY_PATH";

          shellHook = ''
            export CGO_ENABLED=0
            echo "Devshell activated."
          '';
        };
    };
}
