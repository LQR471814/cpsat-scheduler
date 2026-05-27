package main

import (
	"fmt"

	"google.golang.org/protobuf/types/descriptorpb"
)

const (
	message_type_duration  = ".google.protobuf.Duration"
	message_type_timestamp = ".google.protobuf.Timestamp"
)

type TypeStore struct {
	messages map[string]*descriptorpb.DescriptorProto
	enums    map[string]*descriptorpb.EnumDescriptorProto
}

func NewTypeStore() TypeStore {
	return TypeStore{
		messages: make(map[string]*descriptorpb.DescriptorProto),
		enums:    make(map[string]*descriptorpb.EnumDescriptorProto),
	}
}

func (s TypeStore) exploreEnum(parent string, enum *descriptorpb.EnumDescriptorProto) {
	path := fmt.Sprintf("%s.%s", parent, enum.GetName())
	s.enums[path] = enum
}

func (s TypeStore) exploreMessage(parent string, msg *descriptorpb.DescriptorProto) {
	path := fmt.Sprintf("%s.%s", parent, msg.GetName())
	s.messages[path] = msg
	for _, nestedMsg := range msg.GetNestedType() {
		s.exploreMessage(path, nestedMsg)
	}
	for _, nestedEnum := range msg.GetEnumType() {
		s.exploreEnum(path, nestedEnum)
	}
}

func (s TypeStore) Touch(file *descriptorpb.FileDescriptorProto) {
	for _, msg := range file.GetMessageType() {
		s.exploreMessage("", msg)
	}
	for _, enum := range file.GetEnumType() {
		s.exploreEnum("", enum)
	}
}

func (s TypeStore) GetMessageType(typename string) *descriptorpb.DescriptorProto {
	return s.messages[typename]
}

func (s TypeStore) GetEnumType(typename string) *descriptorpb.EnumDescriptorProto {
	return s.enums[typename]
}
