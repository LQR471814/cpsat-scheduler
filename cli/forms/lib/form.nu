# @usetype "./types.nu"
# @usetype "./callback.nu"

use field.nu
use callback.nu
use types.nu

# creates a command that validates all fields before returning the form
#
# @input list<types.Field>
# @output types.Command
export def "done cmd" []: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
	# @type list<types.Field>
	let fields: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> = $in

	let validation = $fields
		| each {|field|
			if $field.ops.validate == null { return }
			# @type types.Field
			let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $field
			$"let err = (field typed read) | ($field.ops.validate | callback run)
if $err != null {
	error make $err
}"
		}
		| where $it != null
		| str join "\n"

	let output = $fields
		| each {|field|
			# @type types.Field
			let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $field
			$"\t'($field.id)': (field state access)"
		}
		| str join "\n"

	let body = $"($validation)
{
($output)
} | util save form output
exit"
	{
		desc: "Validate and submit form."
		group: control
		aliases: [d]
		closure: {
			name: done
			params: []
			body: $body
			in: {type: "nothing"}
			out: {type: "nothing"}
			env: false
			export: false
		}
	}
}

# @input nothing
# @output types.Command
export def "cancel cmd" []: nothing -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
	let body = "if not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }
null | util save form output
exit # nu-lint-ignore: exit_only_in_main"

	{
		desc: "Abort submission and discard changes."
		group: control
		aliases: [c]
		closure: {
			name: cancel
			params: []
			body: $body
			in: {type: "nothing"}
			out: {type: "nothing"}
			env: false
			export: false
		}
	}
}

# @input list<types.Field>
# @output types.Command
export def status []: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
	# @type list<types.Field>
	let fields: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> = $in
	let body = $fields
		| each {|field|
			# @type types.Field
			let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $field
			let valid = if $field.ops.validate != null {
				$"let err = ($fields.ops.validate | callback run)
if $err != null {
	util print error $err
}"
			}
			[
				$"util print label '($field.display_name) [($field.group)]'"
				$"util print desc '($field.desc)'"
				$"($field | field typed read) | ($field | field display value callback) | print"
				$valid
				"print ''"
			]
				| where $it != null
				| str join "\n"
		}
		| str join "\n"
	{
		desc: "Show the current form status."
		group: control
		aliases: [s]
		closure: {
			name: status
			params: []
			in: {type: "nothing"}
			out: {type: "nothing"}
			body: $body
			env: false
			export: false
		}
	}
}

# type InteractiveField = record<
#   field: types.Field
#   interact: callback.Callback
# >
#
# @input list<InteractiveField>
# @output types.Command
export def next []: list<record<field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>, interact: record<expr: string>>> -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
	# @type list<InteractiveField>
	let fields: list<record<field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>, interact: record<expr: string>>> = $in

	# pick next form field w/ err
	# print error and abort if validate throws after filling

	let steps = $fields
		| each {|row|
			# @type types.Field
			let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $row.field
			# @type callback.Callback
			let interact: record<expr: string> = $row.interact

			$"if \(($field | field cmd validate)\) != null {
	($interact | callback run)
	let err = ($field | field cmd validate)
	if $err != null {
		$err | util print error
		return false
	}
	return (next)
}"
		}
		| str join "\n"
	let body = $"($steps)
return true"
	{
		desc: "Fill in the next unfilled fields interactively."
		group: control
		aliases: [n]
		closure: {
			name: next
			params: []
			in: {type: "nothing"}
			out: {type: "bool"}
			body: $body
			env: false
			export: false
		}
	}
}

# @input types.Form
# @output callback.Callback
def "default prompt prefix" []: record<name: string, params: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> -> record<expr: string> {
	callback make [] $"$\"\($prompt_prefix\) \\\(($in.name)\\\) \($in | do $default_prompt_prefix\)\""
}

# @input types.Form
# @output string
def setup []: record<name: string, params: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> -> string {
	# @type types.Form
	let form: record<name: string, params: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> = $in

	# @type types.TypeDef
	let form_input_shape: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> = {
		type: record
		fields: [
			{
				key: prompt_prefix
				value: {type: string}
			}
			{
				key: params
				value: $form.params
			}
		]
	}

	$"let __input: ($form_input_shape | types render) = util get form params

let prompt_prefix = $__input.prompt_prefix
let params = $__input.params

let default_prompt_prefix = $env.PROMPT_COMMAND
$env.PROMPT_COMMAND = ($form | default prompt prefix | $in.expr)

($form.init | default '')"
}

# @input types.CommandDef
# @output string
export def "render command def" []: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool> -> string {
	# @type types.CommandDef
	let cmd: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool> = $in

	let export: string = if $cmd.export { "export " } else { "" }
	let envflag: string = if $cmd.env { "--env " } else { "" }
	let params: string = $cmd.params
		| each { types render }
		| str join " "
	let in_type: string = $cmd.in
		| types render
	let out_type: string = $cmd.out
		| types render
	let body = $cmd.body

	$"($export)def ($envflag)'($cmd.name)' [($params)] ($in_type) -> ($out_type) {
($body)
}"
}

# @input types.Form
# @output string
export def render []: record<name: string, params: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> -> string {
	# @type types.Form
	let form: record<name: string, params: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> = $in

	let uses = $form.use
		| each { $"use '($in)'" }
		| str join "\n"
	let setup = $form | setup
	let cmds: string = $form.commands
		| each { render command def }
		| str join "\n\n"

	$"use index.nu
use ../../lib/util.nu
use ../../proto/apipb/api.gen.nu
($uses)

($cmds)

($setup)"
}

