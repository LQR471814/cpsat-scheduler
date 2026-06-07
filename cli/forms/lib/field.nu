# nu-lint-ignore-file: check_typed_flag_before_use

# @usetype "./types.nu"
# @usetype "./callback.nu"

use callback.nu

# @input types.Field
# @output string
def "state access" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> string {
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
export def "typed read" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> string {
	$"read ($in.id)"
}

# @input types.Field
# @output string
export def "typed write" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> string {
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
			body: $"($field | typed read) | ($in.ops.validate | callback run)"
			in: {type: "nothing"}
			out: {type: oneof, positional: [string "nothing"]}
			env: false
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
# @output callback.Callback
def "default interact setter" [desc: string, --multiline]: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> -> record<expr: string> {
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
				label: {
					text: "type def"
					span: (metadata $type).span
				}
			}
		}
	}
	callback make [] $body
}

# @input types.Field
# @output types.Command
# @param callback callback.Callback
export def "cmd interact set" [--callback: record<expr: string>, --multiline]: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
	# @type types.Field
	let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in

	# @type callback.Callback
	let callback: record<expr: string> = $callback | default {
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
	| ($callback | callback run)
	| ($field | typed write)"
			in: {type: "nothing"}
			out: {type: "nothing"}
			env: false
			export: false
		}
	}
}

# @input types.Field
# @output types.Command
# @param callback callback.Callback
#
# NOTE: callback should be: nothing -> oneof<list_entry, nothing>
#
# if it returns null, it means to cancel
export def "cmd interact list add" [callback: record<expr: string>]: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
	# @type types.Field
	let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in

	if $field.type.name != list and $field.type.name != table {
		error make {
			msg: "input field type must be of either list or table"
			label: {
				text: "input field type name"
				span: (metadata $field.type.name).span
			}
		}
	}

	{
		desc: $"Add a value to list ($field.id) interactively."
		group: $field.group
		aliases: []
		closure: {
			name: $"add ($field.id)"
			params: []
			body: $"let chosen = ($callback | callback run)
if $chosen == null { return }
$state
	| append $chosen
	| ($field | typed write)"
			in: {type: "nothing"}
			out: {type: "nothing"}
			env: false
			export: false
		}
	}
}

# @input types.Field
# @output types.Command
# @param id callback.Callback
# @param name callback.Callback
#
# if it returns null, it means to cancel
export def "cmd interact list remove" [id: record<expr: string> name: record<expr: string>]: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
	# @type types.Field
	let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in

	if $field.type.name != list and $field.type.name != table {
		error make {
			msg: "input field type must be of either list or table"
			label: {
				text: "input field type"
				span: (metadata $field.type.name).span
			}
		}
	}

	{
		desc: $"Remove a value from list ($field.id) interactively."
		group: $field.group
		aliases: []
		closure: {
			name: $"remove ($field.id)"
			params: []
			body: $"let state = ($field | typed read)
let chosen = $state
	| each {|row|
		{
			id: \($row | ($id | callback run)\)
			name: \($row | ($name | callback run)\)
		}
	}
	| util choose table --header '($field.desc)'
if $chosen == null { return }
$state
	| where \($it | ($id | callback run)\) != $chosen.id
	| ($field | typed write)"
			in: {type: "nothing"}
			out: {type: "nothing"}
			env: false
			export: false
		}
	}
}

# @input types.Field
# @output types.Command
export def "cmd interact list list" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
	# @type types.Field
	let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in
	{
		desc: $"List the values of ($field.id)."
		group: $field.group
		aliases: []
		closure: {
			name: $"list ($field.id)"
			params: []
			body: $"($field | typed read) | table -e | print"
			in: {type: "nothing"}
			out: {type: "nothing"}
			env: false
			export: false
		}
	}
}

# TODO: finish this later
#
# @input types.Field
# @output types.Command
# @param edit callback.Callback
export def "cmd interact list edit" [edit: record<expr: string>]: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
	# @type types.Field
	let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in
	{
		desc: $"Choose a value of ($field.id) to edit."
		group: $field.group
		aliases: []
		closure: {
			name: $"edit ($field.id)"
			params: []
			body: $"($field | typed read) | table -e | print"
			in: {type: "nothing"}
			out: {type: "nothing"}
			env: false
			export: false
		}
	}
}

# @input types.TypeDef
# @output callback.Callback
def "default display value callback" []: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> -> record<expr: string> {
	let type = $in.type
	let body = match $type {
		string => { "util print desc $in" }
		int | float | number => { "util print number $in" }
		bool => { "util print bool $in" }
		datetime => { "util print date $in" }
		duration => { "util print duration $in" }
		record | table => { "table -e | print" }
		_ => {
			error make {
				msg: $"unsupported type ($type)"
				label: {
					text: "input type name"
					span: (metadata $type).span
				}
			}
		}
	}
	callback make [] $body
}

# display value callback gives the display value callback for a given field
#
# @input types.Field
# @output callback.Callback
export def "display value callback" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<expr: string> {
	# @type types.Field
	let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in
	$field.ops.validate | default { default display value callback }
}
