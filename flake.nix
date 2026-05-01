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
