export def "type optional" []: any -> any {
	{
		type: oneof
		positional: [$in {type: "nothing"}]
	}
}

export def "type proto timestamp" []: nothing -> any {
	{
		type: record
		fields: [[key value];
			[seconds {type: int}]
			[nanos {type: int}]
		]
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

const self_path = path self

# path relative-to doesn't work properly with arbitrary paths right now
def relative-to [from: string, to: string]: nothing -> string {
	uv run python -c $"
from pathlib import Path
import os
print\(os.path.relpath\(Path\('($to)'\), Path\('($from)'\)\)\)"
		| complete
		| get stdout
		| str trim
}

def "lib dir" []: path -> path {
	let from_path = $in
	let self_dir: path = $self_path | path dirname
	let lib_path: path = $self_dir | path join ../lib | path expand
	relative-to $from_path $lib_path
}

export def "gen form" [script_path: path]: any -> nothing { # nu-lint-ignore: missing_in_type
	let self_dir: path = $self_path | path dirname
	let gen_bin: path = $self_dir | path join ../../cmd/gen/form | path expand

	let target_dir = $script_path | path dirname
	let basename: string = $script_path | path basename | str replace .spec.nu ""
	let lib_dir = $target_dir | lib dir

	$in | insert use [
			($lib_dir | path join util.nu)
			($lib_dir | path join state.nu)
			]
		| to json
		| go run $gen_bin
		| save ($target_dir | path join $"($basename).gen.nu") --force
}
