# @usetype "./types.nu"

# @input types.Field
# @output string
export def "state access" [] {
	$"$env.__state_($in.id)"
}

# @input types.Field
# @output types.Command
export def "cmd read" [] {
	# @type types.Field
	let field = $in
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
export def "cmd write" [] {
	# @type types.Field
	let field = $in
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
# @output types.Command
export def "cmd validate" [] {
	# @type types.Field
	let field = $in
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
			body: $"read ($in.id) | do ($in.ops.validate | to nuon --serialize)"
			in: {type: "nothing"}
			out: $in.type
			env: true
			export: false
		}
	}
}

# @input types.Field
# @output list<types.Command>
export def "cmds core" [] {
	[
		($in | cmd read)
		($in | cmd write)
		($in | cmd validate)
	]
		| where $it != null
}

# @input types.TypeDef
# @output closure
def "default interact setter" [] {

}

# @input types.Field
# @output types.Command
# @param setter closure
export def "cmd interact set" [--callback: closure] {
	# @type types.Field
	let field = $in

	let callback == null {
		$field.type | default interact setter
	} else {
		$callback
	}

	{
		desc: $"Set ($field.id) interactively."
		group: $field.group
		aliases: []
		closure: {
			name: $"set ($field.id)"
			params: []
			body: $"($in | state access)
	| do ($callback | to nuon --serialize)
	| write ($field.id)"
			in: {type: "nothing"}
			out: {type: "nothing"}
			env: true
			export: false
		}
	}
}
