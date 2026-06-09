use index.nu
use ../lib/nav.nu
use ../../lib/util.nu
use ../../lib/proto/apipb/api.gen.nu



def --env 'read required' []: nothing -> record {
$env.__state_required
}

def --env 'write required' []: record -> nothing {
$env.__state_required = $field
}

def --env 'validate required' []: nothing -> oneof<string, nothing> {
read required | do {||
        let v = $in
        if ($v.name | is-empty) {
          return "name cannot be empty"
        }
        if $v.timescale == null {
          return "timescale cannot be empty"
        }
      }
}

def --env 'read optional' []: nothing -> record<state: oneof<nothing, record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>>>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>>>> {
$env.__state_optional
}

def --env 'write optional' []: record<state: oneof<nothing, record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>>>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>>>> -> nothing {
$env.__state_optional = $field
}

def --env 'validate optional' []: nothing -> oneof<string, nothing> {
read optional | do {|| }
}

def --env 'set required' []: nothing -> nothing {
read required
	| do {|| read required | index form task-required }
	| write required
}

def --env 'set optional' []: nothing -> nothing {
read optional
	| do {|| read optional | index form task-optional }
	| write optional
}

def --env 'cancel' []: nothing -> nothing {
if not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }
null | nav save form output
exit # nu-lint-ignore: exit_only_in_main
}

def --env 'done' []: nothing -> nothing {
let err = read required | do {||
        let v = $in
        if ($v.name | is-empty) {
          return "name cannot be empty"
        }
        if $v.timescale == null {
          return "timescale cannot be empty"
        }
      }
if $err != null {
	error make $err
}
let err = read optional | do {|| }
if $err != null {
	error make $err
};do {|| read required
| merge (read optional) } | nav save form output

exit
}

def --env 'status' []: nothing -> nothing {
util print label 'Required Fields []'
util print desc 'Required task fields.'
read required | do {|| table -e | print } | print
let err = read required | do {||
        let v = $in
        if ($v.name | is-empty) {
          return "name cannot be empty"
        }
        if $v.timescale == null {
          return "timescale cannot be empty"
        }
      }
if $err != null {
	util print error $err
}
print ''
util print label 'Optional Fields []'
util print desc 'Optional task fields.'
read optional | do {|| table -e | print } | print
let err = read optional | do {|| }
if $err != null {
	util print error $err
}
print ''
}

def --env 'next' []: nothing -> bool {
if (validate required) != null {
	do {|| set required }
	let err = validate required
	if $err != null {
		util print error $err
		return false
	}
	return (next)
}
if (validate optional) != null {
	do {|| set optional }
	let err = validate optional
	if $err != null {
		util print error $err
		return false
	}
	return (next)
}
return true
}

def --env 'cmds' []: nothing -> table<group: string, name: string, aliases: list<string>, desc: string> {
[[group name aliases desc];["","read required",[],"Get the value of required."]
["","write required",[],"Set the value of required."]
["","validate required",[],"Check if the current value of required has any errors."]
["","read optional",[],"Get the value of optional."]
["","write optional",[],"Set the value of optional."]
["","validate optional",[],"Check if the current value of optional has any errors."]
["","set required",[],"Set required interactively."]
["","set optional",[],"Set optional interactively."]
["control","cancel",["c"],"Abort submission and discard changes."]
["control","done",["d"],"Validate and submit form."]
["control","status",["s"],"Show the current form status."]
["control","next",["n"],"Fill in the next unfilled fields interactively."]]
}

let __input: record<prompt_prefix: string, params: record<state: oneof<nothing, record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>>>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>>>>> = nav get form params

let prompt_prefix: string = $__input.prompt_prefix
let params: record<state: oneof<nothing, record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>>>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>>>> = $__input.params

let default_prompt_prefix: closure = $env.PROMPT_COMMAND
$env.PROMPT_COMMAND = {|| $"($prompt_prefix) \(task\) ($in | do $default_prompt_prefix)" }
$params
| select name desc timescale
| write required

$params
| reject name desc timescale
| write required

cmds | table -e | print

alias c = cancel
alias d = done
alias s = status
alias n = next