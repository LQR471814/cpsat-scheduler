let python_out = (pwd)/cpsat-model/src
let proto: string = (pwd)/proto
let proto_files: list<string> = ls (($proto)/**/*.proto | into glob)
	| get name

python-grpc-tools-protoc -I $proto --python_out $python_out --pyi_out $python_out --grpc_python_out $python_out ...$proto_files
buf generate

