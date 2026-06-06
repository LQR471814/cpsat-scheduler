# @usetype "./types.nu"

# creates a command that validates all fields before returning the form
#
# @input list<types.Field>
# @output types.Command
export def "form done cmd" [] {
	# @type list<types.Field>
	let fields = $in

	let validation = $fields
		| each {|field|
			# @type types.Field
			let field = $field
			$"let err = (field state access) | do ($field.error | to nuon --serialize)
if $err != null {
	error make $err
}"
		}
		| str join "\n"

	let output = $fields
		| each {|field|
			# @type types.Field
			let field = $field
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
export def "form cancel cmd" [] {
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

# TODO: work out simple form "components"
#
# - single value fields, callback getter/setter
# - special value fields (datepicker), callback
# - list fields, callback add/remove/edit/list
#
# these are for "standard" things and are not expected to be extended

# @input types.Field
# @output types.Command
export def "field single field" [] {

}

