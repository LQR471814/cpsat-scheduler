# @usetype "./types.nu"

# creates a command that validates all fields before returning the form
#
# @input list<types.Field>
# @output types.Command
export def "form done cmd" []: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
	# @type list<types.Field>
	let fields: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> = $in

	let validation = $fields
		| each {|field|
			# @type types.Field
			let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $field
			$"let err = (field state access) | do ($field.ops.validate)
if $err != null {
	error make $err
}"
		}
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
			env: true
			export: false
		}
	}
}

# @input nothing
# @output types.Command
export def "form cancel cmd" []: nothing -> record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
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
			env: true
			export: false
		}
	}
}

# - list fields, callback add/remove/edit/list
