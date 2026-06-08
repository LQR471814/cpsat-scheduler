# export type primitive = oneof<string, int, float, duration, datetime, bool, filesize, path>

# choose table allows one to choose a row from a table via fuzzy search
#
# @input table<id: primitive, name: string>
# @output oneof<record<id: primitive, name: string>, nothing>
# @param header string
export def "choose table" [--header: string]: table<id: oneof<string, int, float, duration, datetime, bool, filesize, path>, name: string> -> oneof<record<id: oneof<string, int, float, duration, datetime, bool, filesize, path>, name: string>, nothing> {
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

const TEXT_LABEL_COLOR = 212
const TEXT_DESC_COLOR = 103
const TEXT_ERR_COLOR = 5
const NUM_COLOR = 110
const TRUE_COLOR = 002
const FALSE_COLOR = 210

# print label prints a label to STDOUT
export def "print label" [text: string]: nothing -> nothing {
  gum style --foreground $TEXT_LABEL_COLOR $text --bold
}

# print desc prints a greyed out description to STDOUT
export def "print desc" [text: string]: nothing -> nothing {
  gum style --foreground $TEXT_DESC_COLOR $text
}

# print number prints a number
export def "print number" [value: number]: nothing -> nothing {
  gum style --foreground $NUM_COLOR $value
}

# print bool prints a boolean value
export def "print bool" [value: bool]: nothing -> nothing {
  if $value {
    gum style --foreground $TRUE_COLOR $value
  } else {
    gum style --foreground $FALSE_COLOR $value
  }
}

# print err prints an error message to STDOUT
export def "print error" [text: string]: nothing -> nothing {
  gum style --foreground $TEXT_ERR_COLOR $text
}

# print section title prints a section title
export def "print section title" [text: string]: nothing -> nothing {
  gum style --align center --width 30 --border hidden $text
}

# print date prints a date value (without time)
export def "print date" [date: oneof<datetime, nothing>]: nothing -> nothing {
  if $date == null { return null }
  gum style --foreground $NUM_COLOR ($date | format date %Y-%m-%d)
}

# print duration prints a duration value
export def "print duration" [dur: oneof<duration, nothing>]: nothing -> nothing {
  if $dur == null { return null }
  gum style --foreground $NUM_COLOR ($dur | into string)
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

# input float provides a single float input, does validation, returns
# null if aborted
export def "input float" [placeholder: string]: nothing -> oneof<float, nothing> {
  let result = input text $placeholder
  if $result == null { return null }
  $result | into float
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

# range shift amount translates the range by a given amount
export def "range shift amount" [value: duration]: record<opt: duration, exp: duration, pes: duration> -> record<opt: duration, exp: duration, pes: duration> {
  {
    opt: ($in.opt + $value)
    exp: ($in.exp + $value)
    pes: ($in.pes + $value)
  }
}

# range shift amount translates the range by a given % of the expected value
export def "range shift percent" [percent: float]: record<opt: duration, exp: duration, pes: duration> -> record<opt: duration, exp: duration, pes: duration> {
  range shift amount ($in.exp * ($percent / 100.0))
}

# range widen increases the width of a range by a given %, this is the
# equivalent of scaling by (100 + %) / 100 times
export def "range widen" [percentage_delta: float]: record<opt: duration, exp: duration, pes: duration> -> record<opt: duration, exp: duration, pes: duration> {
  let range = $in
  let factor = (100.0 + $percentage_delta) / 100.0
  $range | range scale $factor
}

# range scale scales a range by a given factor (ex. 2x)
export def "range scale" [factor: float]: record<opt: duration, exp: duration, pes: duration> -> record<opt: duration, exp: duration, pes: duration> {
  let opt_rel = $in.opt - $in.exp
  let pes_rel = $in.pes - $in.exp
  {
    opt: ($in.exp + ($opt_rel * $factor))
    exp: $in.exp
    pes: ($in.exp + ($pes_rel * $factor))
  }
}

# format pert converts a PERT into a string
export def "range format" []: record<opt: duration, exp: duration, pes: duration> -> string {
  $"\(($in.opt), ($in.exp), ($in.pes)\)"
}

def "spin pipe" []: string -> string {
  $"/tmp/cpsat-cli.spinner.($in)"
}

def "spin waiter script" []: string -> string {
  $"#!/bin/sh
cat '($in | spin pipe)' > /dev/null"
}

# spin start starts a spinner asynchronously and returns its id
export def "spin start" []: nothing -> string {
  let id = random chars --length 8
  let path = $id | spin pipe
  mkfifo $path
  $id | spin waiter script | save --force $"($path).sh"
  chmod 0700 $"($path).sh"
  $id
}

# spin stop stops a spinner of the given input id
export def "spin stop" []: string -> nothing {
  let id = $in
  let path = $id | spin pipe
  "" | save --raw --force $path
  rm --force $"($path).sh" $path
}

# spin show synchronously waits for `spin stop` while displaying a spinner animation
export def "spin show" [title: string]: string -> nothing {
  let path = $in | spin pipe
  gum spin --spinner dot --title $title -- $"($path).sh"
}
