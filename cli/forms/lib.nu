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

# field is:
# - id: string
# - display_name: string
# - desc: string
# - display_value: nothing -> string
# - state: nothing -> {unset, set, error}
# - error message -> oneof<string, nothing>

export def "field commands" [] {

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

