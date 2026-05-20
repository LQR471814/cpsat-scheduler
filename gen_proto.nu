let python_out = (pwd)/solver/src
let proto: string = (pwd)/proto

let proto_files: list<string> = ls (($proto)/solver/**/*.proto | into glob) | get name

python-grpc-tools-protoc -I $proto --python_out $python_out --pyi_out $python_out --grpc_python_out $python_out ...$proto_files

buf generate

# move nushell gen files into the right directory
mv api/*.gen.nu cli/lib/
rm api
rm --recursive solver/solverpb
rm --recursive google
