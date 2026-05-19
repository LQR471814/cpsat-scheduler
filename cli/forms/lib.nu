export def "type optional" []: any -> any {
	{
		type: oneof
		positional: [$in {type: "nothing"}]
	}
}

export def "type proto timestamp" []: nothing -> any {
	{
		type: string
	}
}

export def "type proto duration" []: nothing -> any {
	{
		type: string
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

export def "form imports" []: nothing -> list<string> {
	return [
		../../lib/util.nu
		../../lib/state.nu
	]
}

