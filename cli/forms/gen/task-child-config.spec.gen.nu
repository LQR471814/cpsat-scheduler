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

let __input: record<prompt_prefix: string, params: record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, task_id: int>> = nav get form params

let prompt_prefix: string = $__input.prompt_prefix
let params: record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, task_id: int> = $__input.params

let default_prompt_prefix: closure = $env.PROMPT_COMMAND
$env.prompt_prefix = {|| prompt prefix }
$env.PROMPT_COMMAND = do --env {|| $"(prompt prefix) ($in | do $default_prompt_prefix)" }
$env.__state = {}


def "prompt prefix" []: nothing -> string {
$"($prompt_prefix) \(" + "task-child-config" + "\)"
}

def --env "read desc" []: nothing -> oneof<oneof<nothing, string>, nothing> {
$env.__state.desc
}

def --env "write desc" [--skipval(-s)]: oneof<oneof<nothing, string>, nothing> -> nothing {
let new = $in
if $skipval {
  $env.__state.desc = $new
  return
}
let err = $new | do --env {|| if $in == null {
  'description cannot be null'
} }
if $err != null {
  util print error $err
  return
}
$env.__state.desc = $new
}

def --env "validate desc" []: nothing -> oneof<string, nothing> {
read desc | do --env {|| if $in == null {
  'description cannot be null'
} }
}

def --env "read deadline" []: nothing -> oneof<nothing, datetime> {
$env.__state.deadline
}

def --env "write deadline" [--skipval(-s)]: oneof<nothing, datetime> -> nothing {
let new = $in
if $skipval {
  $env.__state.deadline = $new
  return
}
let err = $new | do --env {|| null }
if $err != null {
  util print error $err
  return
}
$env.__state.deadline = $new
}

def --env "validate deadline" []: nothing -> oneof<string, nothing> {
read deadline | do --env {|| null }
}

def --env "read exp_cost" []: nothing -> oneof<oneof<nothing, int>, nothing> {
$env.__state.exp_cost
}

def --env "write exp_cost" [--skipval(-s)]: oneof<oneof<nothing, int>, nothing> -> nothing {
let new = $in
if $skipval {
  $env.__state.exp_cost = $new
  return
}
let err = $new | do --env {|| if ($in == null) {
  'expected cost cannot be null'
} }
if $err != null {
  util print error $err
  return
}
$env.__state.exp_cost = $new
}

def --env "validate exp_cost" []: nothing -> oneof<string, nothing> {
read exp_cost | do --env {|| if ($in == null) {
  'expected cost cannot be null'
} }
}

def --env "read children" []: nothing -> list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>> {
$env.__state.children
}

def --env "write children" [--skipval(-s)]: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>> -> nothing {
let new = $in
if $skipval {
  $env.__state.children = $new
  return
}
let err = $new | do --env {|| if ($in | is-empty) {
  'cannot have a children config that contains no children. if you wish to specify a task with 0 duration, consider adding a child with explicit PERT range of (opt: 0, exp: 0, pes: 0).'
} }
if $err != null {
  util print error $err
  return
}
$env.__state.children = $new
}

def --env "validate children" []: nothing -> oneof<string, nothing> {
read children | do --env {|| if ($in | is-empty) {
  'cannot have a children config that contains no children. if you wish to specify a task with 0 duration, consider adding a child with explicit PERT range of (opt: 0, exp: 0, pes: 0).'
} }
}

def --env "set desc" []: nothing -> nothing {
let new = read desc | do --env {|| do --env {|| do --env {|| util input text "Description of this possible set of children." } } }
if $new == null { return }
$new | write desc 
}

def --env "set exp_cost" []: nothing -> nothing {
let new = read exp_cost | do --env {|| do --env {|| do --env {|| util input int "The expected cost to be added to the global sum if the parent task is scheduled after the deadline." } } }
if $new == null { return }
$new | write exp_cost 
}

def --env "set deadline" []: nothing -> nothing {
let new = read deadline | do --env {|| do --env {|| util choose date } }
if $new == null { return }
$new | write deadline 
}

def --env "new child" []: nothing -> nothing {

let result = {
  id: null
  state: null
} | index form task
if $result == null { return }

let id = {
  id: null
  profile_id: (profile read)
  state: $result
} | api.gen API SaveTask | get id
read children
| append {
  id: $id
  name: $result.name
}
| write children 

null
    
}

def --env "add children" []: nothing -> nothing {
let orig = read children
let chosen = do --env {|| {
  type: CHILD
  task_id: $params.task_id
}
| api.gen API ListPossibleRelatives
| get entries
| util choose table --header 'Choose a child to add:' }
if $chosen == null { return }
$orig
	| append $chosen
	| write children 
}

def --env "remove children" []: nothing -> nothing {
let orig = read children
let chosen = $orig
  | enumerate
	| each {|row|
		$row.item | do --env {|| $in } $row.index
	}
	| util choose table --header ('Remove: ' + "The children that are part of this configuration. They must be scheduled within the bounds of the parent's scheduled timescale instance.")
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
let err = read desc | do --env {|| if $in == null {
  'description cannot be null'
} }
if $err != null {
  util print label "Description"
	util print error $err
  return
}
let err = read deadline | do --env {|| null }
if $err != null {
  util print label "Deadline"
	util print error $err
  return
}
let err = read exp_cost | do --env {|| if ($in == null) {
  'expected cost cannot be null'
} }
if $err != null {
  util print label "Expected Cost"
	util print error $err
  return
}
let err = read children | do --env {|| if ($in | is-empty) {
  'cannot have a children config that contains no children. if you wish to specify a task with 0 duration, consider adding a child with explicit PERT range of (opt: 0, exp: 0, pes: 0).'
} }
if $err != null {
  util print label "Children"
	util print error $err
  return
}
{"desc": (read desc)
"deadline": (read deadline)
"exp_cost": (read exp_cost)
"children": (read children)} | nav save form output

exit
}

def --env "status" []: nothing -> nothing {
util print label "Description"
util print desc "Description of this possible set of children."
read desc | do --env {|| match ($in | describe | parse --regex `^(?<type>\w+)` | get 0.type) {
"nothing" => { $in | do {|| print } }
"string" => { $in | do {|| print $in } }
"nothing" => { $in | do {|| print } }
} } | print
let err = read desc | do --env {|| if $in == null {
  'description cannot be null'
} }
if $err != null {
	util print error $err
}
print ''
util print label "Deadline"
util print desc "If the parent is scheduled after the deadline, the expected cost will be added to the total cost."
read deadline | do --env {|| match ($in | describe | parse --regex `^(?<type>\w+)` | get 0.type) {
"nothing" => { $in | do {|| print } }
"datetime" => { $in | do {|| util print date $in } }
} } | print
let err = read deadline | do --env {|| null }
if $err != null {
	util print error $err
}
print ''
util print label "Expected Cost"
util print desc "The expected cost to be added to the global sum if the parent task is scheduled after the deadline."
read exp_cost | do --env {|| match ($in | describe | parse --regex `^(?<type>\w+)` | get 0.type) {
"nothing" => { $in | do {|| print } }
"int" => { $in | do {|| util print number $in } }
"nothing" => { $in | do {|| print } }
} } | print
let err = read exp_cost | do --env {|| if ($in == null) {
  'expected cost cannot be null'
} }
if $err != null {
	util print error $err
}
print ''
util print label "Children"
util print desc "The children that are part of this configuration. They must be scheduled within the bounds of the parent's scheduled timescale instance."
read children | do --env {|| table --expand | print } | print
let err = read children | do --env {|| if ($in | is-empty) {
  'cannot have a children config that contains no children. if you wish to specify a task with 0 duration, consider adding a child with explicit PERT range of (opt: 0, exp: 0, pes: 0).'
} }
if $err != null {
	util print error $err
}
print ''
}

def --env "next" []: nothing -> bool {
if (validate desc) != null {
	do --env {|| set desc }
	let err = validate desc
	if $err != null {
		return false
	}
	return (next)
}
if (validate exp_cost) != null {
	do --env {|| set exp_cost }
	let err = validate exp_cost
	if $err != null {
		return false
	}
	return (next)
}
if (validate deadline) != null {
	do --env {|| set deadline }
	let err = validate deadline
	if $err != null {
		return false
	}
	return (next)
}
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
[[group name aliases desc];["","read desc","","Get the value of desc."]
["","write desc","","Set the value of desc."]
["","validate desc","","Check if the current value of desc has any errors."]
["","read deadline","","Get the value of deadline."]
["","write deadline","","Set the value of deadline."]
["","validate deadline","","Check if the current value of deadline has any errors."]
["","read exp_cost","","Get the value of exp_cost."]
["","write exp_cost","","Set the value of exp_cost."]
["","validate exp_cost","","Check if the current value of exp_cost has any errors."]
["","read children","","Get the value of children."]
["","write children","","Set the value of children."]
["","validate children","","Check if the current value of children has any errors."]
["","set desc","","Set desc interactively."]
["","set exp_cost","","Set exp_cost interactively."]
["","set deadline","","Set deadline interactively."]
["","new child","nc","Create a new task and add it to the list of children."]
["","add children","","Add a value to list children interactively."]
["","remove children","","Remove a value from list children interactively."]
["control","cancel","c","Abort submission and discard changes."]
["control","done","d","Validate and submit form."]
["control","status","s","Show the current form status."]
["control","next","n","Fill in the next unfilled fields interactively."]]
}

util print section title "task-child-config"
cmds | table --expand | print
$env.__state.desc = do --env {|| $params.desc }
$env.__state.deadline = do --env {|| $params.deadline }
$env.__state.exp_cost = do --env {|| $params.exp_cost }
$env.__state.children = do --env {|| $params.children }

alias nc = new child
alias c = cancel
alias d = done
alias s = status
alias n = next