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

let __input: record<prompt_prefix: string, params: nothing> = nav get form params

let prompt_prefix: string = $__input.prompt_prefix
let params: nothing = $__input.params

let default_prompt_prefix: closure = $env.PROMPT_COMMAND
$env.prompt_prefix = {|| prompt prefix }
$env.PROMPT_COMMAND = do --env {|| $"(prompt prefix) ($in | do $default_prompt_prefix)" }
$env.__state = {}


def "prompt prefix" []: nothing -> string {
$"($prompt_prefix) \(" + "progress-update" + "\)"
}

def --env "read modified" []: nothing -> list<record<id: int, state: record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>>>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>>>> {
$env.__state.modified
}

def --env "write modified" [--skipval(-s)]: list<record<id: int, state: record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>>>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>>>> -> nothing {
let new = $in
if $skipval {
  $env.__state.modified = $new
  return
}
let err = $new | do --env {||
        if ($in | is-empty) {
          'must modify at least one task in a progress update'
        }
      }
if $err != null {
  util print error $err
  return
}
$env.__state.modified = $new
}

def --env "validate modified" []: nothing -> oneof<string, nothing> {
read modified | do --env {||
        if ($in | is-empty) {
          'must modify at least one task in a progress update'
        }
      }
}

def --env "update task" []: int -> nothing {
let updated = {
  id: $in
  state: ({id: $in} | api.gen API ReadTask | get state)
} | index form task

if $updated == null { return }
read modified
| append $updated
| write modified 
}

def --env "pick scheduled" []: nothing -> nothing {
let last_ckpt = {profile: (profile read)} | api.gen API GetLastCheckpoint
  | get time
if $last_ckpt == null {
  error make {msg: 'last checkpoint does not exist'}
}
let timescale = util choose timescale
let chosen = {
  profile_id: (profile read)
  timescale: $timescale
  start: $last_ckpt
  end: (date now)
} | api.gen API ListScheduledTasks | get entries | util choose table --header 'Choose a task:' | get id?
if $chosen == null { return }
$chosen | update task
}

export def --env "pick task" [--start(-s): datetime --end(-e): datetime]: nothing -> nothing {
let timescale = util choose timescale
let now = date now
let chosen = {
  profile_id: (profile read)
  timescale: $timescale
  start: ($start | default ($now - 1wk))
  end: ($end | default ($now + 1wk))
} | api.gen API ListScheduledTasks | get entries | util choose table --header 'Choose a task:' | get id?
if $chosen == null { return }
$chosen | update task
}

def --env "progress log" []: nothing -> string {
read modified
| each {|task|
  "($task.id) ($task.state.name)"
}
| str join '
'
    
}

def --env "cancel" [--no-prompt(-y)]: nothing -> nothing {
if not $no_prompt and not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }

null | nav save form output
exit # nu-lint-ignore: exit_only_in_main
}

def --env "done" []: nothing -> nothing {
let err = read modified | do --env {||
        if ($in | is-empty) {
          'must modify at least one task in a progress update'
        }
      }
if $err != null {
  util print label "Modified Tasks"
	util print error $err
  return
}
{"modified": (read modified)} | nav save form output

exit
}

def --env "status" []: nothing -> nothing {
util print label "Modified Tasks"
util print desc "The tasks that have been modified during this progress update."
read modified | do --env {|| table --expand | print } | print
let err = read modified | do --env {||
        if ($in | is-empty) {
          'must modify at least one task in a progress update'
        }
      }
if $err != null {
	util print error $err
}
print ''
}

def --env "next" []: nothing -> bool {
if (validate modified) != null {
	do --env {|| add modified }
	let err = validate modified
	if $err != null {
		return false
	}
	return (next)
}
return true
}

def --env "cmds" []: nothing -> table<group: string, name: string, aliases: string, desc: string> {
[[group name aliases desc];["","read modified","","Get the value of modified."]
["","write modified","","Set the value of modified."]
["","validate modified","","Check if the current value of modified has any errors."]
["","update task","","Update a task."]
["","pick scheduled","ps","Pick a task scheduled in the time since the last progress update."]
["","pick task","pt","Pick any task within 1 week (or specifiable) window of the current time."]
["","progress log","","Compute the progress log message for the modifications made to tasks."]
["control","cancel","c","Abort submission and discard changes."]
["control","done","d","Validate and submit form."]
["control","status","s","Show the current form status."]
["control","next","n","Fill in the next unfilled fields interactively."]]
}

util print section title "progress-update"
cmds | table --expand | print
$env.__state.modified = do --env {|| [] }

alias ps = pick scheduled
alias pt = pick task
alias c = cancel
alias d = done
alias s = status
alias n = next