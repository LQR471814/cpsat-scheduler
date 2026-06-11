# @usetype "../../lib/proto/apipb/api.gen.nu"

use index.nu
use ../lib/nav.nu
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

let __input: record<prompt_prefix: string, params: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>> = nav get form params

let prompt_prefix: string = $__input.prompt_prefix
let params: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>> = $__input.params

let default_prompt_prefix: closure = $env.PROMPT_COMMAND
$env.prompt_prefix = {|| prompt prefix }
$env.PROMPT_COMMAND = do --env {|| $"(prompt prefix) ($in | do $default_prompt_prefix)" }


def "prompt prefix" []: nothing -> string {
$"($prompt_prefix) \(" + "task-children-configs" + "\)"
}

def --env "read children" []: nothing -> list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>> {
$env.__state_children
}

def --env "write children" [--skipval(-s)]: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>> -> nothing {
let new = $in
if $skipval {
  $env.__state_children = $new
  return
}
let err = $new | do --env {|| null }
if $err != null {
  util print error $err
  return
}
$env.__state_children = $new
}

def --env "validate children" []: nothing -> oneof<string, nothing> {
read children | do --env {|| null }
}

def --env "add children" []: nothing -> nothing {
let orig = read children
let chosen = $orig | do --env {|| index form task-child-config }
if $chosen == null { return }
$orig
	| append $chosen
	| write children 
}

def --env "remove children" []: nothing -> nothing {
let orig = read children
let chosen = $orig
	| each {|row|
		($row | do --env {|| $in })
	}
	| util choose table --header ('Remove: ' + "List of children configurations.")
if $chosen == null { return }
if not (util confirm --prompt $"Are you sure you wish to remove ($chosen.name)?") { return }
$orig
	| where ($it | do --env {|| $in } | get id) != $chosen.id
	| write children 
}

def --env "cancel" [--no-prompt(-y)]: nothing -> nothing {
if not $no_prompt and not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }

null | nav save form output
exit # nu-lint-ignore: exit_only_in_main
}

def --env "done" []: nothing -> nothing {
let err = read children | do --env {|| null }
if $err != null {
  util print label "Children Configs"
	util print error $err
  return
}
{"children": (read children)} | nav save form output

exit
}

def --env "status" []: nothing -> nothing {
util print label "Children Configs"
util print desc "List of children configurations."
read children | do --env {|| table -e | print } | print
let err = read children | do --env {|| null }
if $err != null {
	util print error $err
}
print ''
}

def --env "next" []: nothing -> bool {
if (validate children) != null {
	do --env {|| add children }
	let err = validate children
	if $err != null {
		return false
	}
	return (next)
}
return true
}

def --env "cmds" []: nothing -> table<group: string, name: string, aliases: string, desc: string> {
[[group name aliases desc];["","read children","","Get the value of children."]
["","write children","","Set the value of children."]
["","validate children","","Check if the current value of children has any errors."]
["","add children","","Add a value to list children interactively."]
["","remove children","","Remove a value from list children interactively."]
["control","cancel","c","Abort submission and discard changes."]
["control","done","d","Validate and submit form."]
["control","status","s","Show the current form status."]
["control","next","n","Fill in the next unfilled fields interactively."]]
}

util print section title "task-children-configs"
cmds | table -e | print
$env.__state_children = do --env {|| $params }

alias c = cancel
alias d = done
alias s = status
alias n = next