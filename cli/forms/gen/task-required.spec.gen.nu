# @usetype "../../lib/proto/apipb/api.gen.nu"

use index.nu
use ../lib/nav.nu
use ../../lib/profile.nu
use ../../lib/util.nu
use ../../lib/proto/apipb/api.gen.nu



$env.config.keybindings = $env.config.keybindings | append {
  name: ctrl_d_hook
  modifier: control
  keycode: char_d
  mode: [emacs vi_insert vi_normal]
  event: {
    send: executehostcommand
    cmd: 'cancel'
  }
}

let __input: record<prompt_prefix: string, params: record<name: oneof<string, nothing>, desc: oneof<string, nothing>, timescale: oneof<int, nothing>>> = nav get form params

let prompt_prefix: string = $__input.prompt_prefix
let params: record<name: oneof<string, nothing>, desc: oneof<string, nothing>, timescale: oneof<int, nothing>> = $__input.params

let default_prompt_prefix: closure = $env.PROMPT_COMMAND
$env.prompt_prefix = {|| prompt prefix }
$env.PROMPT_COMMAND = do --env {|| $"(prompt prefix) ($in | do $default_prompt_prefix)" }
$env.__state = {}


def "prompt prefix" []: nothing -> string {
$"($prompt_prefix) \(" + "task-required" + "\)"
}

def --env "read name" []: nothing -> oneof<string, nothing> {
$env.__state.name
}

def --env "write name" [--skipval(-s)]: oneof<string, nothing> -> nothing {
let new = $in
if $skipval {
  $env.__state.name = $new
  return
}
let err = $new | do --env {||
        if ($in | is-empty) {
          "name cannot be empty"
        }
      }
if $err != null {
  util print error $err
  return
}
$env.__state.name = $new
}

def --env "validate name" []: nothing -> oneof<string, nothing> {
read name | do --env {||
        if ($in | is-empty) {
          "name cannot be empty"
        }
      }
}

def --env "read desc" []: nothing -> oneof<string, nothing> {
$env.__state.desc
}

def --env "write desc" [--skipval(-s)]: oneof<string, nothing> -> nothing {
let new = $in
if $skipval {
  $env.__state.desc = $new
  return
}
let err = $new | do --env {||
        if ($in == null) {
          "description should not be null"
        }
      }
if $err != null {
  util print error $err
  return
}
$env.__state.desc = $new
}

def --env "validate desc" []: nothing -> oneof<string, nothing> {
read desc | do --env {||
        if ($in == null) {
          "description should not be null"
        }
      }
}

def --env "read timescale" []: nothing -> oneof<int, nothing> {
$env.__state.timescale
}

def --env "write timescale" [--skipval(-s)]: oneof<int, nothing> -> nothing {
let new = $in
if $skipval {
  $env.__state.timescale = $new
  return
}
let err = $new | do --env {|| 
let unit: int = $in
if ($unit == null) {
  "timescale should not be null"
}
let possible = util timescales | get id
if not ($unit in $possible) {
  $"the given timescale is not one of the possible timescales: ($possible)"
} }
if $err != null {
  util print error $err
  return
}
$env.__state.timescale = $new
}

def --env "validate timescale" []: nothing -> oneof<string, nothing> {
read timescale | do --env {|| 
let unit: int = $in
if ($unit == null) {
  "timescale should not be null"
}
let possible = util timescales | get id
if not ($unit in $possible) {
  $"the given timescale is not one of the possible timescales: ($possible)"
} }
}

def --env "set name" []: nothing -> nothing {
let new = read name | do --env {|| do --env {|| util input text "The name of the task." } }
if $new == null { return }
$new | write name 
}

def --env "set desc" []: nothing -> nothing {
let new = read desc | do --env {|| do --env {|| util input multiline "The description of the task." } }
if $new == null { return }
$new | write desc 
}

def --env "set timescale" []: nothing -> nothing {
let new = read timescale | do --env {|| util timescales
| util choose table --header 'Timescale unit (upper-bound for task duration):'
| get id? }
if $new == null { return }
$new | write timescale 
}

def --env "cancel" [--no-prompt(-y)]: nothing -> nothing {
if not $no_prompt and not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }

null | nav save form output
exit # nu-lint-ignore: exit_only_in_main
}

def --env "done" []: nothing -> nothing {
let err = read name | do --env {||
        if ($in | is-empty) {
          "name cannot be empty"
        }
      }
if $err != null {
  util print label "Name"
	util print error $err
  return
}
let err = read desc | do --env {||
        if ($in == null) {
          "description should not be null"
        }
      }
if $err != null {
  util print label "Description"
	util print error $err
  return
}
let err = read timescale | do --env {|| 
let unit: int = $in
if ($unit == null) {
  "timescale should not be null"
}
let possible = util timescales | get id
if not ($unit in $possible) {
  $"the given timescale is not one of the possible timescales: ($possible)"
} }
if $err != null {
  util print label "Timescale Unit"
	util print error $err
  return
}
{"name": (read name)
"desc": (read desc)
"timescale": (read timescale)} | nav save form output

exit
}

def --env "status" []: nothing -> nothing {
util print label "Name"
util print desc "The name of the task."
read name | do --env {|| match ($in | describe | parse --regex `^(?<type>\w+)` | get 0.type) {
"string" => { $in | do {|| print $in } }
"nothing" => { $in | do {|| print } }
} } | print
let err = read name | do --env {||
        if ($in | is-empty) {
          "name cannot be empty"
        }
      }
if $err != null {
	util print error $err
}
print ''
util print label "Description"
util print desc "The description of the task."
read desc | do --env {|| match ($in | describe | parse --regex `^(?<type>\w+)` | get 0.type) {
"string" => { $in | do {|| print $in } }
"nothing" => { $in | do {|| print } }
} } | print
let err = read desc | do --env {||
        if ($in == null) {
          "description should not be null"
        }
      }
if $err != null {
	util print error $err
}
print ''
util print label "Timescale Unit"
util print desc "Should be the upper-bound for task duration."
read timescale | do --env {|| match ($in | describe | parse --regex `^(?<type>\w+)` | get 0.type) {
"int" => { $in | do {|| util print number $in } }
"nothing" => { $in | do {|| print } }
} } | print
let err = read timescale | do --env {|| 
let unit: int = $in
if ($unit == null) {
  "timescale should not be null"
}
let possible = util timescales | get id
if not ($unit in $possible) {
  $"the given timescale is not one of the possible timescales: ($possible)"
} }
if $err != null {
	util print error $err
}
print ''
}

def --env "next" []: nothing -> bool {
if (validate name) != null {
	do --env {|| set name }
	let err = validate name
	if $err != null {
		return false
	}
	return (next)
}
if (validate desc) != null {
	do --env {|| set desc }
	let err = validate desc
	if $err != null {
		return false
	}
	return (next)
}
if (validate timescale) != null {
	do --env {|| set timescale }
	let err = validate timescale
	if $err != null {
		return false
	}
	return (next)
}
return true
}

def --env "cmds" []: nothing -> table<group: string, name: string, aliases: string, desc: string> {
[[group name aliases desc];["","read name","","Get the value of name."]
["","write name","","Set the value of name."]
["","validate name","","Check if the current value of name has any errors."]
["","read desc","","Get the value of desc."]
["","write desc","","Set the value of desc."]
["","validate desc","","Check if the current value of desc has any errors."]
["","read timescale","","Get the value of timescale."]
["","write timescale","","Set the value of timescale."]
["","validate timescale","","Check if the current value of timescale has any errors."]
["","set name","","Set name interactively."]
["","set desc","","Set desc interactively."]
["","set timescale","","Set timescale interactively."]
["control","cancel","c","Abort submission and discard changes."]
["control","done","d","Validate and submit form."]
["control","status","s","Show the current form status."]
["control","next","n","Fill in the next unfilled fields interactively."]]
}

util print section title "task-required"
cmds | table --expand | print
$env.__state.name = do --env {|| $params.name }
$env.__state.desc = do --env {|| $params.desc }
$env.__state.timescale = do --env {|| $params.timescale }

alias c = cancel
alias d = done
alias s = status
alias n = next