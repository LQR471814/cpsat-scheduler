let python_out = (pwd)/solver/src # nu-lint-ignore: dont_mix_different_effects
let proto: string = (pwd)/proto

print "gen python..."

let solverpb: list<string> = ls (($proto)/solverpb/**/*.proto | into glob) | get name

let commonpb: list<string> = ls (($proto)/commonpb/**/*.proto | into glob) | get name

python-grpc-tools-protoc -I $proto --python_out $python_out --pyi_out $python_out --grpc_python_out $python_out ...$solverpb ...$commonpb

print "gen buf..."

buf generate

# move nushell gen files into the right directory
mv apipb/*.gen.nu cli/lib
rm apipb
rm --recursive solverpb
rm --recursive commonpb
rm --recursive google
