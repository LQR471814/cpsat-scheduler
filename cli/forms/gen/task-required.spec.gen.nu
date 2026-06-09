use index.nu
use ../lib/nav.nu
use ../../lib/util.nu
use ../../lib/proto/apipb/api.gen.nu



def --env 'read name' []: nothing -> oneof<string, nothing> {
$env.__state_name
}

def --env 'write name' []: oneof<string, nothing> -> nothing {
let new = $in
let err = $new | do --env {||
        if ($in | is-empty) {
          "name cannot be empty"
        }
      }
if $err != null {
  $err | util print error
  return
}
$env.__state_name = $new
}

def --env 'validate name' []: nothing -> oneof<string, nothing> {
read name | do --env {||
        if ($in | is-empty) {
          "name cannot be empty"
        }
      }
}

def --env 'read desc' []: nothing -> oneof<string, nothing> {
$env.__state_desc
}

def --env 'write desc' []: oneof<string, nothing> -> nothing {
let new = $in
let err = $new | do --env {|| }
if $err != null {
  $err | util print error
  return
}
$env.__state_desc = $new
}

def --env 'validate desc' []: nothing -> oneof<string, nothing> {
read desc | do --env {|| }
}

def --env 'read unit' []: nothing -> oneof<int, nothing> {
$env.__state_unit
}

def --env 'write unit' []: oneof<int, nothing> -> nothing {
let new = $in
let err = $new | do --env {|| }
if $err != null {
  $err | util print error
  return
}
$env.__state_unit = $new
}

def --env 'validate unit' []: nothing -> oneof<string, nothing> {
read unit | do --env {|| }
}

def --env 'set name' []: nothing -> nothing {
read name
	| do --env {|| {|| input text 'The name of the task.' } }
	| write name
}

def --env 'set desc' []: nothing -> nothing {
read desc
	| do --env {|| {|| input text 'The description of the task.' } }
	| write desc
}

def --env 'set unit' []: nothing -> nothing {
read unit
	| do --env {|| {|| util input int 'Timescale unit (should be the upper-bound for task duration).' } }
	| write unit
}

def --env 'cancel' [param.key]: nothing -> nothing {
if not $no_prompt and not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }
null | nav save form output
exit # nu-lint-ignore: exit_only_in_main
}

def --env 'done' []: nothing -> nothing {
let err = read name | do --env {||
        if ($in | is-empty) {
          "name cannot be empty"
        }
      }
if $err != null {
	error make $err
}
let err = read desc | do --env {|| }
if $err != null {
	error make $err
}
let err = read unit | do --env {|| }
if $err != null {
	error make $err
};	'name': (read name)
	'desc': (read desc)
	'unit': (read unit) | nav save form output

exit
}

def --env 'status' []: nothing -> nothing {
util print label 'Name []'
util print desc 'The name of the task.'
read name | do --env {|| match ($in | describe) {
string => { $in | {|| util print desc $in } }
nothing => { $in | {|| print } }
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
util print label 'Description []'
util print desc 'The description of the task.'
read desc | do --env {|| match ($in | describe) {
string => { $in | {|| util print desc $in } }
nothing => { $in | {|| print } }
} } | print
let err = read desc | do --env {|| }
if $err != null {
	util print error $err
}
print ''
util print label 'Unit []'
util print desc 'Timescale unit (should be the upper-bound for task duration).'
read unit | do --env {|| match ($in | describe) {
int => { $in | {|| util print number $in } }
nothing => { $in | {|| print } }
} } | print
let err = read unit | do --env {|| }
if $err != null {
	util print error $err
}
print ''
}

def --env 'next' []: nothing -> bool {
if (validate name) != null {
	do --env {|| set name }
	let err = validate name
	if $err != null {
		util print error $err
		return false
	}
	return (next)
}
if (validate desc) != null {
	do --env {|| set desc }
	let err = validate desc
	if $err != null {
		util print error $err
		return false
	}
	return (next)
}
if (validate unit) != null {
	do --env {|| set unit }
	let err = validate unit
	if $err != null {
		util print error $err
		return false
	}
	return (next)
}
return true
}

def --env 'cmds' []: nothing -> table<group: string, name: string, aliases: list<string>, desc: string> {
[[group name aliases desc];["","read name",[],"Get the value of name."]
["","write name",[],"Set the value of name."]
["","validate name",[],"Check if the current value of name has any errors."]
["","read desc",[],"Get the value of desc."]
["","write desc",[],"Set the value of desc."]
["","validate desc",[],"Check if the current value of desc has any errors."]
["","read unit",[],"Get the value of unit."]
["","write unit",[],"Set the value of unit."]
["","validate unit",[],"Check if the current value of unit has any errors."]
["","set name",[],"Set name interactively."]
["","set desc",[],"Set desc interactively."]
["","set unit",[],"Set unit interactively."]
["control","cancel",["c"],"Abort submission and discard changes."]
["control","done",["d"],"Validate and submit form."]
["control","status",["s"],"Show the current form status."]
["control","next",["n"],"Fill in the next unfilled fields interactively."]]
}

let __input: record<prompt_prefix: string, params: record<task_id: int, name: oneof<string, nothing>, desc: oneof<string, nothing>, unit: oneof<int, nothing>>> = nav get form params

let prompt_prefix: string = $__input.prompt_prefix
let params: record<task_id: int, name: oneof<string, nothing>, desc: oneof<string, nothing>, unit: oneof<int, nothing>> = $__input.params

let default_prompt_prefix: closure = $env.PROMPT_COMMAND
$env.PROMPT_COMMAND = {|| $"($prompt_prefix) \(task-required\) ($in | do $default_prompt_prefix)" }

cmds | table -e | print

alias c = cancel
alias d = done
alias s = status
alias n = next