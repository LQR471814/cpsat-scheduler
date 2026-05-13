# choose table allows one to choose a row from a table via fuzzy search
export def "choose table" [--header: string]: table<id: int, name: string> -> oneof<record<id: int, name: string>, nothing> {
	let width = ($in | length | math log 10 | math floor) + 1
	let choices: list<string> = $in | each {|x|
		let id_display = $x.id | fill --alignment left --width $width
		let name_display = $x.name
		$"($id_display) - ($name_display)"
	}
	let answer = $choices | str join "\n" | gum filter --header ($header | default "") # nu-lint-ignore: check_typed_flag_before_use
	if ($answer | is-empty) {
		return null
	}
	$answer
		| parse --regex `(?<id>\d+) +- (?<name>.+)`
		| update id { into int }
		| first
}

# print title prints a title to STDOUT
export def "print title" [text: string]: nothing -> nothing {
	gum style --foreground 212 $text --bold
}

# choose date allows the user to choose a date, returns null if aborted
export def "choose date" []: nothing -> oneof<datetime, nothing> {
	let result = datepicker -y -f %Y-%m-%d -d
		| complete
		| $in.stdout
	if ($result | is-empty) {
		return null
	}
	$result | into datetime
}

# input text provides a nice single-line text input, returns null if aborted
export def "input text" [placeholder: string]: nothing -> oneof<string, nothing> {
	let result = gum input --placeholder $placeholder --prompt ""
	if $result == "not submitted" {
		return null
	}
	$result
}

# input multiline provides a nice multi-line text input with ability
# to use editor to input, returns null if aborted
export def "input multiline" [placeholder: string]: nothing -> oneof<string, nothing> {
	let result = gum write --placeholder $placeholder --prompt ""
	if $result == "not submitted" {
		return null
	}
	$result
}

# input int provides a single integer input, does validation, returns
# null if aborted
export def "input int" [placeholder: string]: nothing -> oneof<int, nothing> {
	let result = input text $placeholder
	if not $result {
		return null
	}
	$result | into int
}

# exec form executes a form script with the given env vars, it
# automatically handles output capture and response parsing
export def "exec form" [script: path, vars: record]: nothing -> any { # nu-lint-ignore: missing_output_type
	do { # nu-lint-ignore: try_instead_of_do
		let id = random chars --length 8
		$vars | load-env
		$env.p_out = $"/tmp/cpsat-cli.form-state.($id)"
		nu -e (open $script) # nu-lint-ignore: catch_builtin_error_try
		let res = open $env.p_out | from msgpack # nu-lint-ignore: catch_builtin_error_try
		try { rm $env.p_out }
		$res
	}
}
