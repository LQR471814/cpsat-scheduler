package main

import (
	"io"
	"log"
	"os"

	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/pluginpb"
)

func main() {
	req := &pluginpb.CodeGeneratorRequest{}
	buff, err := io.ReadAll(os.Stdin)
	if err != nil {
		log.Fatal(err)
	}
	err = proto.Unmarshal(buff, req)
	if err != nil {
		log.Fatal(err)
	}

	resp := &pluginpb.CodeGeneratorResponse{}
	doCodeGen(req, resp)

	marshalled, err := proto.Marshal(resp)
	if err != nil {
		log.Fatal(err)
	}
	os.Stdout.Write(marshalled)
}

func doCodeGen(req *pluginpb.CodeGeneratorRequest, resp *pluginpb.CodeGeneratorResponse) {
	supported := uint64(pluginpb.CodeGeneratorResponse_FEATURE_PROTO3_OPTIONAL)
	resp.SupportedFeatures = &supported

	msgs := NewTypeStore()
	for _, f := range req.GetProtoFile() {
		msgs.Touch(f)
	}
	for _, f := range req.GetSourceFileDescriptors() {
		ctx := NewGenContext(msgs, f)
		ctx.Generate(f, resp)
	}
}
