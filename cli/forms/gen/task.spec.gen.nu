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

let __input: record<prompt_prefix: string, params: record<state: record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>>>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>>, id: oneof<int, nothing>, profile_id: int>> = nav get form params

let prompt_prefix: string = $__input.prompt_prefix
let params: record<state: record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>>>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>>, id: oneof<int, nothing>, profile_id: int> = $__input.params

let default_prompt_prefix: closure = $env.PROMPT_COMMAND
$env.prompt_prefix = {|| prompt prefix }
$env.PROMPT_COMMAND = do --env {|| $"(prompt prefix) ($in | do $default_prompt_prefix)" }
let is_creating = $params.id == null

def 'prompt prefix' []: nothing -> string {
$"($prompt_prefix) \(task\)"
}

def --env 'read required' []: nothing -> record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>> {
$env.__state_required
}

def --env 'write required' [--skipval(-s)]: record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>> -> nothing {
let new = $in
if $skipval {
  $env.__state_required = $new
  return
}
let err = $new | do --env {|| 
let v = $in
if ($v.name? | is-empty) {
  return 'name cannot be empty'
}
if $v.timescale? == null {
  return 'timescale cannot be empty'
}
if $env.__tmp_task_id != null {
  return
}

let default_dur_cfg = {
  pert: {pes: 90min, exp: 1hr, opt: 30min}
  deadline: null
  total_cost: 0
}

{
  id: null
  profile_id: $params.profile_id
  state: {
    name: $v.name
    desc: ($v.desc | default '')
    timescale: $v.timescale
    duration_cfg: $default_dur_cfg
    children_cfgs: []
    prereqs: []
    postreqs: []
    parent: null
    start: null
    end: null
  }
}
| api.gen API SaveTask
| get id
| do --env {|| $env.__tmp_task_id = $in } }
if $err != null {
  util print error $err
  return
}
$env.__state_required = $new
}

def --env 'validate required' []: nothing -> oneof<string, nothing> {
read required | do --env {|| 
let v = $in
if ($v.name? | is-empty) {
  return 'name cannot be empty'
}
if $v.timescale? == null {
  return 'timescale cannot be empty'
}
if $env.__tmp_task_id != null {
  return
}

let default_dur_cfg = {
  pert: {pes: 90min, exp: 1hr, opt: 30min}
  deadline: null
  total_cost: 0
}

{
  id: null
  profile_id: $params.profile_id
  state: {
    name: $v.name
    desc: ($v.desc | default '')
    timescale: $v.timescale
    duration_cfg: $default_dur_cfg
    children_cfgs: []
    prereqs: []
    postreqs: []
    parent: null
    start: null
    end: null
  }
}
| api.gen API SaveTask
| get id
| do --env {|| $env.__tmp_task_id = $in } }
}

def --env 'read optional' []: nothing -> record<duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>>>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>> {
$env.__state_optional
}

def --env 'write optional' [--skipval(-s)]: record<duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>>>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>> -> nothing {
let new = $in
if $skipval {
  $env.__state_optional = $new
  return
}
let err = $new | do --env {||
        if $in.duration_cfg == null {
          'optional field duration_cfg must not be null'
        }
      }
if $err != null {
  util print error $err
  return
}
$env.__state_optional = $new
}

def --env 'validate optional' []: nothing -> oneof<string, nothing> {
read optional | do --env {||
        if $in.duration_cfg == null {
          'optional field duration_cfg must not be null'
        }
      }
}

def --env 'set required' []: nothing -> nothing {
let new = read required | do --env {|| 
let new = $in | merge {
  task_id: $env.__tmp_task_id
} | index form task-required
if $new == null {
  cancel -y
}
$new }
if $new == null { return }
$new | write required 
}

def --env 'set optional' []: nothing -> nothing {
let new = read optional | do --env {|| $in | merge {
  task_id: $env.__tmp_task_id
} | index form task-optional }
if $new == null { return }
$new | write optional 
}

def --env 'cancel' [--no-prompt(-y)]: nothing -> nothing {
if not $no_prompt and not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }
do --env {|| if $is_creating and $env.__tmp_task_id != null {
  {id: $env.__tmp_task_id} | api.gen API DeleteTask
} }
null | nav save form output
exit # nu-lint-ignore: exit_only_in_main
}

def --env 'done' []: nothing -> nothing {
let err = read required | do --env {|| 
let v = $in
if ($v.name? | is-empty) {
  return 'name cannot be empty'
}
if $v.timescale? == null {
  return 'timescale cannot be empty'
}
if $env.__tmp_task_id != null {
  return
}

let default_dur_cfg = {
  pert: {pes: 90min, exp: 1hr, opt: 30min}
  deadline: null
  total_cost: 0
}

{
  id: null
  profile_id: $params.profile_id
  state: {
    name: $v.name
    desc: ($v.desc | default '')
    timescale: $v.timescale
    duration_cfg: $default_dur_cfg
    children_cfgs: []
    prereqs: []
    postreqs: []
    parent: null
    start: null
    end: null
  }
}
| api.gen API SaveTask
| get id
| do --env {|| $env.__tmp_task_id = $in } }
if $err != null {
  util print label 'Required Fields:'
	util print error $err
  return
}
let err = read optional | do --env {||
        if $in.duration_cfg == null {
          'optional field duration_cfg must not be null'
        }
      }
if $err != null {
  util print label 'Optional Fields:'
	util print error $err
  return
}
do --env {|| do --env {|| if $is_creating and $env.__tmp_task_id != null {
  {id: $env.__tmp_task_id} | api.gen API DeleteTask
} }
read required
| merge (read optional) } | nav save form output

exit
}

def --env 'status' []: nothing -> nothing {
util print label 'Required Fields'
util print desc 'Required task fields.'
read required | do --env {|| table -e | print } | print
let err = read required | do --env {|| 
let v = $in
if ($v.name? | is-empty) {
  return 'name cannot be empty'
}
if $v.timescale? == null {
  return 'timescale cannot be empty'
}
if $env.__tmp_task_id != null {
  return
}

let default_dur_cfg = {
  pert: {pes: 90min, exp: 1hr, opt: 30min}
  deadline: null
  total_cost: 0
}

{
  id: null
  profile_id: $params.profile_id
  state: {
    name: $v.name
    desc: ($v.desc | default '')
    timescale: $v.timescale
    duration_cfg: $default_dur_cfg
    children_cfgs: []
    prereqs: []
    postreqs: []
    parent: null
    start: null
    end: null
  }
}
| api.gen API SaveTask
| get id
| do --env {|| $env.__tmp_task_id = $in } }
if $err != null {
	util print error $err
}
print ''
util print label 'Optional Fields'
util print desc 'Optional task fields.'
read optional | do --env {|| table -e | print } | print
let err = read optional | do --env {||
        if $in.duration_cfg == null {
          'optional field duration_cfg must not be null'
        }
      }
if $err != null {
	util print error $err
}
print ''
}

def --env 'next' []: nothing -> bool {
if (validate required) != null {
	do --env {|| set required }
	let err = validate required
	if $err != null {
		return false
	}
	return (next)
}
if (validate optional) != null {
	do --env {|| set optional }
	let err = validate optional
	if $err != null {
		return false
	}
	return (next)
}
return true
}

def --env 'cmds' []: nothing -> table<group: string, name: string, aliases: string, desc: string> {
[[group name aliases desc];["","read required","","Get the value of required."]
["","write required","","Set the value of required."]
["","validate required","","Check if the current value of required has any errors."]
["","read optional","","Get the value of optional."]
["","write optional","","Set the value of optional."]
["","validate optional","","Check if the current value of optional has any errors."]
["","set required","","Set required interactively."]
["","set optional","","Set optional interactively."]
["control","cancel","c","Abort submission and discard changes."]
["control","done","d","Validate and submit form."]
["control","status","s","Show the current form status."]
["control","next","n","Fill in the next unfilled fields interactively."]]
}

util print section title 'task'
cmds | table -e | print
$env.__state_required = do --env {|| $params.state
| select name desc timescale
   }
$env.__state_optional = do --env {|| $params.state
| reject name desc timescale }

$params.id | do --env {|| $env.__tmp_task_id = $in }

set required

if (validate required) != null {
  cancel -y
}

alias c = cancel
alias d = done
alias s = status
alias n = next