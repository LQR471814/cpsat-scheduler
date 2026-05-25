let python_out = (pwd)/solver/src
let proto: string = (pwd)/proto

let proto_files: list<string> = ls (($proto)/solverpb/**/*.proto | into glob) | get name

print "gen python..."

python-grpc-tools-protoc -I $proto --python_out $python_out --pyi_out $python_out --grpc_python_out $python_out ...$proto_files

print "gen buf..."

buf generate

# move nushell gen files into the right directory
mv apipb/*.gen.nu cli/lib
rm apipb
rm --recursive solverpb
rm --recursive commonpb
rm --recursive google
