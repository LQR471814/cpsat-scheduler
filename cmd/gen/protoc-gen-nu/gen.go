package main

import (
	"cpsat-scheduler/internal/nugen"
	"fmt"
	"io"
	"path/filepath"
	"strings"
	"unicode"
	"unicode/utf8"

	"google.golang.org/protobuf/types/descriptorpb"
	"google.golang.org/protobuf/types/pluginpb"
)

const frontmatter = `const SOCKET_PATH = "/tmp/cpsat-scheduler.api.sock"

const self_path = path self

export def req [api: string, method: string]: any -> any {
    let schema_path = $self_path | path dirname | path join ../../proto
	$in
        | to json --raw
        | buf curl -d @- --unix-socket $SOCKET_PATH --protocol grpc --http2-prior-knowledge --schema $schema_path $"http://localhost/($api)/($method)"
		| from json
}

def "deserialize proto dur" []: string -> duration {
	1sec * ($in | str substring 0..<(($in | str length) - 1) | into float)
}

def "deserialize proto time" []: string -> datetime {
	into datetime | date to-timezone local
}

def "serialize proto dur" []: duration -> string {
    $"($in / 1sec)s"
}

def "serialize proto time" []: datetime -> string {
    format date %+
}
`

const (
	message_type_duration  = ".google.protobuf.Duration"
	message_type_timestamp = ".google.protobuf.Timestamp"
)

type GenContext struct {
	messages      map[string]*descriptorpb.DescriptorProto
	messageTypes  map[string]nugen.TypeDef
	serializers   map[string]nugen.Closure
	deserializers map[string]nugen.Closure
}

func newGenContext(file *descriptorpb.FileDescriptorProto) GenContext {
	ctx := GenContext{
		messages:      make(map[string]*descriptorpb.DescriptorProto),
		messageTypes:  make(map[string]nugen.TypeDef),
		serializers:   make(map[string]nugen.Closure),
		deserializers: make(map[string]nugen.Closure),
	}
	for _, msg := range file.GetMessageType() {
		ctx.exploreMessage("", msg)
	}
	return ctx
}

func (c GenContext) exploreMessage(parent string, msg *descriptorpb.DescriptorProto) {
	path := fmt.Sprintf("%s.%s", parent, msg.GetName())
	c.messages[path] = msg
	for _, nested := range msg.GetNestedType() {
		c.exploreMessage(path, nested)
	}
}

func (c GenContext) getFieldSerialize(field *descriptorpb.FieldDescriptorProto) string {
	typeName := field.GetTypeName()
	switch typeName {
	case message_type_duration:
		return "serialize proto dur"
	case message_type_timestamp:
		return "serialize proto time"
	}

	switch field.GetType() {
	// case descriptorpb.FieldDescriptorProto_TYPE_INT64,
	// 	descriptorpb.FieldDescriptorProto_TYPE_SFIXED64:
	// 	return "into int"
	case descriptorpb.FieldDescriptorProto_TYPE_MESSAGE:
		return c.getSerializer(typeName)
	}
	return "$in"
}

func (c GenContext) renderFieldTransform(
	out io.Writer,
	field *descriptorpb.FieldDescriptorProto,
	transformer string,
) {
	// proto3 optional is effectively just syntax sugar for oneof
	optional := field.GetLabel() != descriptorpb.FieldDescriptorProto_LABEL_OPTIONAL || field.OneofIndex != nil
	var question string
	if optional {
		question = "?"
	}

	transform := transformer
	if transform == "$in" {
		return
	}
	if field.GetLabel() == descriptorpb.FieldDescriptorProto_LABEL_REPEATED {
		transform = fmt.Sprintf("each { %s }", transform)
	}
	fmt.Fprintf(
		out,
		"| update %s%s { %s }\n",
		field.GetName(),
		question,
		transform,
	)
}

func (c GenContext) getSerializerInner(msgName string) nugen.Closure {
	var body strings.Builder
	fmt.Fprintln(&body, "$in")

	for _, field := range c.messages[msgName].GetField() {
		c.renderFieldTransform(&body, field, c.getFieldSerialize(field))
	}

	return nugen.Closure{
		Name:   fmt.Sprintf("serialize %s", msgName),
		Params: nil,
		Body:   nugen.Block(body.String()),
		In:     c.convertMessageType(msgName),
		Out:    nugen.AnyType,
	}
}

func (c GenContext) getSerializer(msgName string) string {
	name := fmt.Sprintf("serialize %s", msgName)
	_, exists := c.serializers[msgName]
	if exists {
		return name
	}
	closure := c.getSerializerInner(msgName)
	c.serializers[msgName] = closure
	return name
}

func (c GenContext) getFieldDeserialize(field *descriptorpb.FieldDescriptorProto) string {
	fullTypeName := field.GetTypeName()
	switch fullTypeName {
	case message_type_duration:
		return "deserialize proto dur"
	case message_type_timestamp:
		return "deserialize proto time"
	}
	switch field.GetType() {
	case descriptorpb.FieldDescriptorProto_TYPE_INT64,
		descriptorpb.FieldDescriptorProto_TYPE_SFIXED64:
		return "into int"
	case descriptorpb.FieldDescriptorProto_TYPE_MESSAGE:
		return c.getDeserializer(string(fullTypeName))
	}
	return "$in"
}

func capitalize(str string) string {
	if len(str) == 0 {
		return ""
	}
	firstRune, read := utf8.DecodeRune([]byte(str))
	return string(unicode.ToLower(firstRune)) + str[read:]
}

func toLowerCamelCase(name string) string {
	var out strings.Builder
	var prevSep bool
	for _, c := range name {
		if c == '_' {
			prevSep = true
			continue
		}
		if prevSep {
			prevSep = false
			c = unicode.ToUpper(c)
		}
		out.WriteRune(c)
	}
	return capitalize(out.String())
}

func (c GenContext) getDeserializerInner(msgName string) nugen.Closure {
	var body strings.Builder

	fmt.Fprintln(&body, "$in")

	// rename fields from lowerCamelCase to their original names
	for _, field := range c.messages[msgName].GetField() {
		camelCase := toLowerCamelCase(field.GetName())
		if camelCase == field.GetName() {
			continue
		}

		if field.GetLabel() == descriptorpb.FieldDescriptorProto_LABEL_OPTIONAL {
			fmt.Fprintf(&body, "| if $in.%s? != null { ", camelCase)
		} else {
			fmt.Fprint(&body, "| ")
		}

		fmt.Fprint(&body, "rename --column {")
		fmt.Fprint(&body, camelCase)
		fmt.Fprint(&body, ": ")
		fmt.Fprint(&body, field.GetName())
		fmt.Fprint(&body, "}")

		if field.GetLabel() == descriptorpb.FieldDescriptorProto_LABEL_OPTIONAL {
			fmt.Fprint(&body, " }")
		}
		fmt.Fprintln(&body)
	}

	for _, field := range c.messages[msgName].GetField() {
		deserializer := c.getFieldDeserialize(field)
		c.renderFieldTransform(&body, field, deserializer)
	}

	for _, field := range c.messages[msgName].GetField() {
		// buf curl will omit the field if it is empty list!
		if field.GetLabel() == descriptorpb.FieldDescriptorProto_LABEL_REPEATED {
			fmt.Fprintf(&body, "| default [] %s\n", field.GetName())
		}
	}

	return nugen.Closure{
		Name:   fmt.Sprintf("deserialize %s", msgName),
		Params: nil,
		Body:   nugen.Block(body.String()),
		In:     nugen.AnyType,
		Out:    c.convertMessageType(msgName),
	}
}

func (c GenContext) getDeserializer(msgName string) string {
	name := fmt.Sprintf("deserialize %s", msgName)
	_, exists := c.deserializers[msgName]
	if exists {
		return name
	}
	closure := c.getDeserializerInner(msgName)
	c.deserializers[msgName] = closure
	return name
}

func (c GenContext) convertType(typ descriptorpb.FieldDescriptorProto_Type, typename string) nugen.TypeDef {
	switch typ {
	case descriptorpb.FieldDescriptorProto_TYPE_BOOL:
		return nugen.BoolType
	case descriptorpb.FieldDescriptorProto_TYPE_BYTES:
		return nugen.BinaryType
	case descriptorpb.FieldDescriptorProto_TYPE_FLOAT,
		descriptorpb.FieldDescriptorProto_TYPE_DOUBLE:
		return nugen.FloatType
	case descriptorpb.FieldDescriptorProto_TYPE_INT32,
		descriptorpb.FieldDescriptorProto_TYPE_FIXED32,
		descriptorpb.FieldDescriptorProto_TYPE_UINT32,
		descriptorpb.FieldDescriptorProto_TYPE_SFIXED32,
		descriptorpb.FieldDescriptorProto_TYPE_INT64,
		descriptorpb.FieldDescriptorProto_TYPE_SFIXED64:
		return nugen.IntType
	case descriptorpb.FieldDescriptorProto_TYPE_UINT64,
		descriptorpb.FieldDescriptorProto_TYPE_FIXED64:
		panic("uint64 or fixed64 not supported as nushell cannot fit 64 bits into `int` type")
	case descriptorpb.FieldDescriptorProto_TYPE_ENUM,
		descriptorpb.FieldDescriptorProto_TYPE_STRING:
		return nugen.StringType
	case descriptorpb.FieldDescriptorProto_TYPE_MESSAGE:
		return c.convertMessageType(typename)
	case descriptorpb.FieldDescriptorProto_TYPE_GROUP:
		panic("group is not supported as it is deprecated!")
	default:
		panic(fmt.Errorf("unsupported type: %v", typ))
	}
}

func (c GenContext) handleOneOfInner(
	commonFields []nugen.KeyValue[nugen.TypeDef],
	oneofs [][]*descriptorpb.FieldDescriptorProto,
	idx int,
	buff []*descriptorpb.FieldDescriptorProto,
	out *[]nugen.TypeDef,
) {
	if idx < len(oneofs) {
		current := oneofs[idx]
		for _, field := range current {
			buff[idx] = field
			c.handleOneOfInner(commonFields, oneofs, idx+1, buff, out)
		}
		return
	}

	recordDef := nugen.TypeDef{
		Type:   "record",
		Fields: commonFields,
	}
	for _, chosenField := range buff {
		recordDef.Fields = append(recordDef.Fields, nugen.KeyValue[nugen.TypeDef]{
			Key:   chosenField.GetName(),
			Value: c.convertType(chosenField.GetType(), chosenField.GetTypeName()),
		})
	}
	*out = append(*out, recordDef)
}

func (c GenContext) convertFieldType(field *descriptorpb.FieldDescriptorProto) nugen.KeyValue[nugen.TypeDef] {
	typeValue := c.convertType(field.GetType(), field.GetTypeName())
	switch field.GetLabel() {
	case descriptorpb.FieldDescriptorProto_LABEL_OPTIONAL:
		typeValue = nugen.TypeDef{
			Type: "oneof",
			Positional: []nugen.TypeDef{
				nugen.NullType,
				typeValue,
			},
		}
	case descriptorpb.FieldDescriptorProto_LABEL_REPEATED:
		typeValue = nugen.TypeDef{
			Type:       "list",
			Positional: []nugen.TypeDef{typeValue},
		}
	}
	return nugen.KeyValue[nugen.TypeDef]{
		Key:   field.GetName(),
		Value: typeValue,
	}
}

func (c GenContext) convertMessageTypeInner(msgName string) nugen.TypeDef {
	msg := c.messages[msgName]

	var commonFields []nugen.KeyValue[nugen.TypeDef]
	for _, field := range msg.GetField() {
		if field.OneofIndex != nil && field.GetLabel() != descriptorpb.FieldDescriptorProto_LABEL_OPTIONAL {
			continue
		}
		commonFields = append(commonFields, c.convertFieldType(field))
	}

	out := nugen.TypeDef{Type: "oneof"}

	oneofs := make([][]*descriptorpb.FieldDescriptorProto, len(msg.GetOneofDecl()))
	for _, field := range msg.GetField() {
		if field.OneofIndex == nil {
			continue
		}
		oneofs[*field.OneofIndex] = append(oneofs[*field.OneofIndex], field)
	}

	// we filter oneofs with length 1 because they indicate an optional field
	// which can simply be handled in-field without duplicating the entire
	// record
	var oneofsFiltered [][]*descriptorpb.FieldDescriptorProto
	for _, oneof := range oneofs {
		if len(oneof) == 1 {
			continue
		}
		oneofs = append(oneofs, oneof)
	}

	if len(oneofsFiltered) == 0 {
		return nugen.TypeDef{
			Type:   "record",
			Fields: commonFields,
		}
	}

	buff := make([]*descriptorpb.FieldDescriptorProto, len(oneofsFiltered))
	c.handleOneOfInner(commonFields, oneofsFiltered, 0, buff, &out.Positional)

	return out
}

func (c GenContext) convertMessageType(msgName string) nugen.TypeDef {
	switch msgName {
	case message_type_duration:
		return nugen.DurationType
	case message_type_timestamp:
		return nugen.DatetimeType
	}
	if existing, ok := c.messageTypes[msgName]; ok {
		return existing
	}
	typedef := c.convertMessageTypeInner(msgName)
	c.messageTypes[msgName] = typedef
	return typedef
}

func (c GenContext) convertMethod(service string, m *descriptorpb.MethodDescriptorProto) nugen.Closure {
	var body strings.Builder
	fmt.Fprint(&body, c.getSerializer(m.GetInputType()))
	fmt.Fprintf(&body, ` | req %s %s | `, service, m.GetName())
	fmt.Fprint(&body, c.getDeserializer(m.GetOutputType()))
	return nugen.Closure{
		Export: true,
		Name:   fmt.Sprintf("%s %s", service, m.GetName()),
		Params: nil,
		In:     c.convertMessageType(m.GetInputType()),
		Out:    c.convertMessageType(m.GetOutputType()),
		Body:   nugen.Block(body.String()),
	}
}

func (c GenContext) renderService(out io.Writer, srv *descriptorpb.ServiceDescriptorProto) {
	for _, m := range srv.GetMethod() {
		closure := c.convertMethod(srv.GetName(), m)
		closure.Render(out)
		nugen.RenderMargin(out)
	}
}

func (c GenContext) renderHelpers(out io.Writer) {
	for _, closure := range c.deserializers {
		closure.Render(out)
		nugen.RenderMargin(out)
	}
	for _, closure := range c.serializers {
		closure.Render(out)
		nugen.RenderMargin(out)
	}
}

func (c GenContext) Generate(
	file *descriptorpb.FileDescriptorProto,
	resp *pluginpb.CodeGeneratorResponse,
) {
	var contentBuilder strings.Builder
	fmt.Fprint(&contentBuilder, frontmatter)
	for _, srv := range file.GetService() {
		c.renderService(&contentBuilder, srv)
	}
	c.renderHelpers(&contentBuilder)
	content := contentBuilder.String()

	ext := filepath.Ext(file.GetName())
	basename := file.GetName()[:len(file.GetName())-len(ext)]
	name := fmt.Sprintf("%s.gen.nu", basename)
	resp.File = append(resp.File, &pluginpb.CodeGeneratorResponse_File{
		Name:    &name,
		Content: &content,
	})
}
