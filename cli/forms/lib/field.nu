# nu-lint-ignore-file: check_typed_flag_before_use
# @usetype "./types.nu"

# @input types.Field
# @output string
export def "state access" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> string {
	$"$env.__state_($in.id)"
}

# @input types.Field
# @output types.Command
export def "cmd read" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
	# @type types.Field
	let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in
	if not $field.ops.read {
		return null
	}
	{
		desc: $"Get the value of ($in.id)."
		group: $in.group
		aliases: []
		closure: {
			name: $"read ($in.id)"
			params: []
			body: ($in | state access)
			in: {type: "nothing"}
			out: $in.type
			env: true
			export: false
		}
	}
}

# @input types.Field
# @output types.Command
export def "cmd write" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
	# @type types.Field
	let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in
	if not $field.ops.write {
		return null
	}
	{
		desc: $"Set the value of ($in.id)."
		group: $in.group
		aliases: []
		closure: {
			name: $"write ($in.id)"
			params: []
			body: $"($in | state access) = $in"
			in: $in.type
			out: {type: "nothing"}
			env: true
			export: false
		}
	}
}

# @input types.Field
# @output string
def "typed read" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> string {
	$"read ($in.id)"
}

# @input types.Field
# @output string
def "typed write" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> string {
	$"write ($in.id)"
}

# @input types.Field
# @output types.Command
export def "cmd validate" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
	# @type types.Field
	let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in
	if $field.ops.validate == null {
		return null
	}
	{
		desc: $"Check if the current value of ($in.id) has any errors."
		group: $in.group
		aliases: []
		closure: {
			name: $"validate ($in.id)"
			params: []
			body: $"($field | typed read) | do ($in.ops.validate.body)"
			in: {type: "nothing"}
			out: {type: oneof, positional: [string "nothing"]}
			env: true
			export: false
		}
	}
}

# @input types.Field
# @output list<types.Command>
export def "cmds core" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> list<record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>> {
	[
		($in | cmd read)
		($in | cmd write)
		($in | cmd validate)
	]
		| where $it != null
}

# @input types.TypeDef
# @output string
def "default interact setter" [desc: string, --multiline]: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> -> string {
	let type = $in.type
	let body = match $type {
		string => {
			if $multiline {
				$"input multiline '($desc)'"
			} else {
				$"input text '($desc)'"
			}
		}
		int => {
			$"util input int '($desc)'"
		}
		float | number => {
			$"util input float '($desc)'"
		}
		bool => {
			$"util confirm --prompt '($desc)'"
		}
		datetime => {
			# TODO: add desc support to datepicker
			"util choose date"
		}
		_ => {
			error make {
				msg: $"unsupported type ($type)"
				label: {}
			}
		}
	}
	$"{|| ($body) }"
}

# @input types.Field
# @output types.Command
# @param callback types.Callback
export def "cmd interact set" [--callback: record<expr: string>, --multiline]: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
	# @type types.Field
	let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in

	let callback: string = $callback.body? | default {
		if $multiline {
			$field.type | default interact setter $field.desc --multiline
		} else {
			$field.type | default interact setter $field.desc
		}
	}

	{
		desc: $"Set ($field.id) interactively."
		group: $field.group
		aliases: []
		closure: {
			name: $"set ($field.id)"
			params: []
			body: $"($field | typed read)
	| do ($callback)
	| ($field | typed write)"
			in: {type: "nothing"}
			out: {type: "nothing"}
			env: true
			export: false
		}
	}
}

# @input types.Field
# @output types.Command
#
# @param choices types.Callback
#
# param entry should be of type: <list entry> -> table<id: primitive, name: string>
export def "cmd interact list add" [choices: record<expr: string>]: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
	# @type types.Field
	let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in

	if $field.type.name != list and $field.type.name != table {
		error make {
			msg: "input field type must be of either list or table"
			label: {}
		}
	}

	{
		desc: $"Add a value to list ($field.id) interactively."
		group: $field.group
		aliases: []
		closure: {
			name: $"set ($field.id)"
			params: []
			body: $"let state = ($field | typed read)
let chosen = $state
	| util choose table --header '($field.desc)'
if $chosen == null { return }
$state
	| append $chosen
	| ($field | typed write)"
			in: {type: "nothing"}
			out: {type: "nothing"}
			env: true
			export: false
		}
	}
}

# @input closure
# @output types.Callback
export def "callback closure" []: closure -> record<expr: string> {
	{expr: (to nuon --serialize)}
}

# @input nothing
# @output types.Callback
# @param params list<string>
# @param body string
export def callback [params: list<string> body: string]: nothing -> record<expr: string> {
	let params = $params | str join " "
	{
		expr: $"{|($params)| ($body) }"
	}
}
