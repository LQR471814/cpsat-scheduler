# export type TypeDef = oneof<
#   record<
#     type: string,
#     fields: list<KeyValue<any>>,
#     positional: list<any>
#   >
#   record<
#     type: string,
#     positional: list<any>
#   >
#   record<
#     type: string,
#     fields: list<KeyValue<any>>,
#   >
#   record<
#     type: string,
#   >
# >

# export type KeyValue<T> = record<key: string, value: T>

# export type Closure = record<
#   name: string
#   params: list<KeyValue<TypeDef>>
#   body: string
#   in: TypeDef
#   out: TypeDef
#   env: bool
#   export: bool
# >

# export type Command = record<
#   desc: string
#   group: string
#   aliases: list<string>
#   closure: Closure
# >

# validate should return string or null
#
# export type Field = record<
#   id: string
#   display_name: string
#   desc: string
#   group: string
#   type: TypeDef
#   display_value: closure
#	ops: record<
# 		read: bool
#		write: bool
#		validate: oneof<closure, nothing>
# 	>
# >

