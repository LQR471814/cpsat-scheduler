export def "type optional" []: any -> any {
	{
		type: oneof
		positional: [$in {type: "nothing"}]
	}
}

export def "type entry record" []: nothing -> any {
	{
		type: record
		fields: [[key value];
			[id {type: int}]
			[name {type: string}]
		]
	}
}

export def "type entry table" []: nothing -> any {
	{
		type: table
		fields: [[key value];
			[id {type: int}]
			[name {type: string}]
		]
	}
}

# type TypeDef = record<
#   type: string,
#   fields: list<KeyValue<any>>,
#   positional: list<any>
# >

# type KeyValue<T> = record<key: string, value: T>

# type Closure = record<
#   name: string
#   params: list<KeyValue<TypeDef>>
#   body: string
#   in: TypeDef
#   out: TypeDef
#   env: bool
#   export: bool
# >

# type Command = record<
#   desc: string
#   group: string
#   aliases: list<string>
#   closure: Closure
# >

# type Field = record<
#   id: string
#   display_name: string
#   desc: string
#   group: string
#   type: TypeDef
#   display_value: closure
#   state: closure
#   error: closure
# >

# - display_value: nothing -> string
# - state: nothing -> {unset, set, error}
# - error message: nothing -> oneof<string, nothing>
#
# @input list<Field>
# @output list<Command>
export def "typed state cmds" []: list<record<id: string, display_name: string, desc: string, display_value: closure, state: closure, error: closure>> -> list<record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>>>, body: string, in: record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, out: record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, env: bool, export: bool>>> {
	each {|field|
		# @param field Field
		[
			{
				desc: $field.desc
				group: $field.group
				aliases: []
				closure: {
					name: $"read ($field.id)"
					params: []
					body: $"$env.__state_($field.id)"
					in: {type: "nothing"}
					out: $field.type
					env: true
					export: false
				}
			}
			{
				desc: $field.desc
				group: $field.group
				aliases: []
				closure: {
					name: $"write ($field.id)"
					params: []
					body: $"$env.__state_($field.id) = $in"
					in: $field.type
					out: {type: "nothing"}
					env: true
					export: false
				}
			}
		]
	}
	| flatten
}

# TODO: add template for standard form controls (all separate from each other)
# - submit, cancel, next
#
# allow for integration with validation?
# how to handle side effects?
# single "beforeSubmit" and "beforeCancel" callback?

# TODO: work out simple form "components"
#
# - single value fields, callback getter/setter
# - special value fields (datepicker), callback
# - list fields, callback add/remove/edit/list
#
# these are for "standard" things and are not expected to be extended
#
# how to validate? simple "validate" callback?

