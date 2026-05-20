# choose table allows one to choose a row from a table via fuzzy search
export def "choose table" [--header: string]: table<id: int, name: string> -> oneof<record<id: int, name: string>, nothing> {
    if ($in | is-empty) {
        print "no choices possible"
        return null
    }
    let width = ($in | length | math log 10 | math floor) + 1
    let choices: list<string> = $in | each {|x|
        let id_display = $x.id | fill --alignment left --width $width
        let name_display = $x.name
        $"($id_display) - ($name_display)"
    }
    let answer = $choices
        | str join "\n"
        | try {
            if $header != null {
                gum filter --header $header
            } else {
                gum filter
            }
        } catch { null }
    if ($answer | is-empty) {
        return null
    }
    $answer | parse --regex `(?<id>\d+) +- (?<name>.+)` | update id { into int } | first
}


# print label prints a label to STDOUT
export def "print label" [text: string]: nothing -> nothing { gum style --foreground 212 $text --bold }


# print section title prints a section title
export def "print section title" [text: string]: nothing -> nothing { gum style --align center --width 30 --border hidden $text }


# print date prints a date value (without time)
export def "print date" [date: oneof<datetime, nothing>]: nothing -> nothing {
    if $date == null { return null }
    gum style --foreground 121 ($date | format date %Y-%m-%d)
}


# print duration prints a duration value
export def "print duration" [dur: oneof<duration, nothing>]: nothing -> nothing {
    if $dur == null { return null }
    gum style --foreground 138 ($dur | into string)
}


# choose date allows the user to choose a date, returns null if aborted
export def "choose date" []: nothing -> oneof<datetime, nothing> {
    let result = datepicker -y -f %Y-%m-%d -d | complete | $in.stdout
    if ($result | is-empty) {
        return null
    }
    $result | into datetime
}


# input text provides a nice single-line text input, returns null if aborted
export def "input text" [placeholder: string]: nothing -> oneof<string, nothing> {
    let result = try { gum input --placeholder $placeholder --prompt "" } catch { null }
    if $result == null {
        return null
    }
    $result
}


# input multiline provides a nice multi-line text input with ability
# to use editor to input, returns null if aborted
export def "input multiline" [placeholder: string]: nothing -> oneof<string, nothing> {
    let result = try { gum write --placeholder $placeholder --prompt "" } catch { null }
    if $result == null {
        return null
    }
    $result
}


# input int provides a single integer input, does validation, returns
# null if aborted
export def "input int" [placeholder: string]: nothing -> oneof<int, nothing> {
    let result = input text $placeholder
    if $result == null { return null }
    $result | into int
}


# confirm prompts the user to confirm, returns true if user accepted, false if
# rejected
export def confirm [--prompt: string]: nothing -> bool {
    try {
        if $prompt != null {
            gum confirm $prompt
        } else {
            gum confirm
        }
        true
    } catch { false }
}


# exec form executes a form script with the given env vars, it
# automatically handles output capture and response parsing
export def "exec form" [script: path, params: any]: nothing -> any { # nu-lint-ignore: missing_output_type, add_type_hints_arguments
    do { # nu-lint-ignore: try_instead_of_do
        let id = random chars --length 8
        load-env {
			p_in: $"/tmp/cpsat-cli.form-state.in.($id)"
			p_out: $"/tmp/cpsat-cli.form-state.out.($id)"
		}
        $params | to nuon | save $env.p_in # nu-lint-ignore: catch_builtin_error_try
        nu -e $"source '($script)'"
        let res = open $env.p_out | from nuon # nu-lint-ignore: catch_builtin_error_try
        try {
            rm $env.p_in
            rm $env.p_out
        }
        $res
    }
}


# get form params gets the input parameters of a form
export def "get form params" []: nothing -> any { # nu-lint-ignore: missing_output_type
    open $env.p_in | from nuon # nu-lint-ignore: catch_builtin_error_try
}


# save form output saves the output of a form into the output file
export def "save form output" []: any -> nothing {
    to nuon | save $env.p_out # nu-lint-ignore: catch_builtin_error_try
}


