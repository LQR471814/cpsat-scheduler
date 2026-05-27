The `protoc` generator writes `CodeGeneratorRequest` into STDIN
and expects a `CodeGeneratorResponse` in STDOUT.

- `CodeGeneratorRequest`:
    - `ProtoFile` -> `[]FileDescriptorProto`:
        - File descriptors all the known proto files.
    - `SourceFileDescriptor` -> `[]FileDescriptorProto`:
        - File descriptors for the proto files that should be
          generated.
    - `FileToGenerate` -> `[]string`
        - Import path for protos to be generated.
- `FileDescriptorProto`:
    - Describes a proto file.
    - `Name` -> `string`:
        - Import path for proto file.
    - `Dependency` -> `[]string`
        - List of import paths to dependencies of the file.
    - `MessageType` -> `[]DescriptorProto`
    - `EnumType` -> `[]EnumDescriptorProto`
    - `Service` -> `[]ServiceDescriptorProto`
- `DescriptorProto`:
    - `Name` -> `string`:
        - Non-qualified name of the message.
    - `Field` -> `[]FieldDescriptorProto`:
        - Fields of the message.
    - `NestedType` -> `[]DescriptorProto`:
        - Nested messages
    - `EnumType` -> `[]EnumDescriptorProto`:
        - Nested enums
    - `OneofDecl` -> `[]OneofDescriptorProto`:
        - Oneof blocks
        - Does not actually specify which fields are part of it,
          you must examine the `FieldDescriptorProto.OneofIdx` to
          find out.
- `EnumDescriptorProto`
    - `Name` -> `string`:
        - Non-qualified name
    - `Value` -> `[]EnumValueDescriptorProto`
- `ServiceDescriptorProto`
    - `Name` -> `string`
    - `Method` -> `[]MethodDescriptorProto`
- `FieldDescriptorProto`
    - `Name` -> `*string`
    - `Number` -> `*int32`
    - `Label` -> `*FieldDescriptorProto_Label`
        - `FieldDescriptorProto_Label` (enum):
            - `FieldDescriptorProto_LABEL_OPTIONAL`
            - `FieldDescriptorProto_LABEL_REPEATED`
            - `FieldDescriptorProto_LABEL_REQUIRED`
    - `TypeName` -> `*string`
    - `OneofIndex` -> `*int32`
    - `JsonName` -> `string`
    - `Proto3Optional` -> `*bool`
        - If true, indicates that the field should be part of a
          "synthetic oneof".
- `MethodDescriptorProto`
    - `Name` -> `*string`
    - `InputType` -> `*string`
        - Fully qualified name
    - `OutputType` -> `*string`
        - Fully qualified name

Request handling:

1. Map all file protos into module paths.
2. For each source file proto:
    - `source` all `Dependency`
    - Generate serialize for all `MessageType`

