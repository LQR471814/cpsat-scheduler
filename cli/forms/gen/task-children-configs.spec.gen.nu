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

let __input: record<prompt_prefix: string, params: record<task_id: int, children: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>>> = nav get form params

let prompt_prefix: string = $__input.prompt_prefix
let params: record<task_id: int, children: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>> = $__input.params

let default_prompt_prefix: closure = $env.PROMPT_COMMAND
$env.prompt_prefix = {|| prompt prefix }
$env.PROMPT_COMMAND = do --env {|| $"(prompt prefix) ($in | do $default_prompt_prefix)" }
$env.__state = {}


def "prompt prefix" []: nothing -> string {
$"($prompt_prefix) \(" + "task-children-configs" + "\)"
}

def --env "read configs" []: nothing -> list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>> {
$env.__state.configs
}

def --env "write configs" [--skipval(-s)]: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>> -> nothing {
let new = $in
if $skipval {
  $env.__state.configs = $new
  return
}
let err = $new | do --env {|| null }
if $err != null {
  util print error $err
  return
}
$env.__state.configs = $new
}

def --env "validate configs" []: nothing -> oneof<string, nothing> {
read configs | do --env {|| null }
}

def --env "add configs" []: nothing -> nothing {
let orig = read configs
let chosen = do --env {|| {
  task_id: $params.task_id
  desc: null
  deadline: null
  exp_cost: null
  children: []
} | index form task-child-config }
if $chosen == null { return }
$orig
	| append $chosen
	| write configs 
}

def --env "remove configs" []: nothing -> nothing {
let orig = read configs
let chosen = $orig
  | enumerate
	| each {|row|
		$row.item | do --env {|idx|
          {id: $idx name: $in.desc}
        } $row.index
	}
	| util choose table --header ('Remove: ' + "List of children configurations.")
if $chosen == null { return }
if not (util confirm --prompt $"Are you sure you wish to remove ($chosen.name)?") { return }
$orig
	| where ($it | do --env {|idx|
          {id: $idx name: $in.desc}
        } | get id) != $chosen.id
	| write configs 
}

def --env "cancel" [--no-prompt(-y)]: nothing -> nothing {
if not $no_prompt and not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }

null | nav save form output
exit # nu-lint-ignore: exit_only_in_main
}

def --env "done" []: nothing -> nothing {
let err = read configs | do --env {|| null }
if $err != null {
  util print label "Children Configs"
	util print error $err
  return
}
do --env {|| read configs } | nav save form output

exit
}

def --env "status" []: nothing -> nothing {
util print label "Children Configs"
util print desc "List of children configurations."
read configs | do --env {|| table --expand | print } | print
let err = read configs | do --env {|| null }
if $err != null {
	util print error $err
}
print ''
}

def --env "next" []: nothing -> bool {
if (validate configs) != null {
	do --env {|| add configs }
	let err = validate configs
	if $err != null {
		return false
	}
	return (next)
}
return true
}

def --env "cmds" []: nothing -> table<group: string, name: string, aliases: string, desc: string> {
[[group name aliases desc];["","read configs","","Get the value of configs."]
["","write configs","","Set the value of configs."]
["","validate configs","","Check if the current value of configs has any errors."]
["","add configs","","Add a value to list configs interactively."]
["","remove configs","","Remove a value from list configs interactively."]
["control","cancel","c","Abort submission and discard changes."]
["control","done","d","Validate and submit form."]
["control","status","s","Show the current form status."]
["control","next","n","Fill in the next unfilled fields interactively."]]
}

util print section title "task-children-configs"
cmds | table --expand | print
$env.__state.configs = do --env {|| $params.children }

alias c = cancel
alias d = done
alias s = status
alias n = next