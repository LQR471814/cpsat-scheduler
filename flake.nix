{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs =
    { self, nixpkgs }:
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
        in
        pkgs.mkShell {
          name = "devenv";
          buildInputs = libs;
          nativeBuildInputs = (
            with pkgs;
            [
              pkg-config
              sqlc

              protobuf
              protoc-gen-go
              protoc-gen-go-grpc
              python313Packages.grpcio-tools
              buf

              protoc-gen-nu
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
