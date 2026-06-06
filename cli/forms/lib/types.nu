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

# export type Callback = record<expr: string>

# validate should return string or null
#
# export type Field = record<
#   id: string
#   display_name: string
#   desc: string
#   group: string
#   type: TypeDef
#   display_value: Callback
#	ops: record<
# 		read: bool
#		write: bool
#		validate: oneof<Callback, nothing>
# 	>
# >

# @input nothing
# @output TypeDef
export def optional []: nothing -> oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> {
	{
		type: oneof
		positional: [$in {type: "nothing"}]
	}
}

# @input nothing
# @output TypeDef
export def "entry record" []: nothing -> oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> {
	{
		type: record
		fields: [[key value];
			[id {type: int}]
			[name {type: string}]
		]
	}
}

# @input nothing
# @output TypeDef
export def "entry table" []: nothing -> oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> {
	{
		type: table
		fields: [[key value];
			[id {type: int}]
			[name {type: string}]
		]
	}
}
