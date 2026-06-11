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

let __input: record<prompt_prefix: string, params: record<prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, nothing>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, task_id: int>> = nav get form params

let prompt_prefix: string = $__input.prompt_prefix
let params: record<prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, nothing>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, task_id: int> = $__input.params

let default_prompt_prefix: closure = $env.PROMPT_COMMAND
$env.prompt_prefix = {|| prompt prefix }
$env.PROMPT_COMMAND = do --env {|| $"(prompt prefix) ($in | do $default_prompt_prefix)" }


def 'prompt prefix' []: nothing -> string {
$"($prompt_prefix) \(task-optional\)"
}

def --env 'read parent' []: nothing -> oneof<record<id: int, name: string>, nothing> {
$env.__state_parent
}

def --env 'write parent' [--skipval(-s)]: oneof<record<id: int, name: string>, nothing> -> nothing {
let new = $in
if $skipval {
  $env.__state_parent = $new
  return
}
let err = $new | do --env {|| null }
if $err != null {
  util print error $err
  return
}
$env.__state_parent = $new
}

def --env 'validate parent' []: nothing -> oneof<string, nothing> {
read parent | do --env {|| null }
}

def --env 'read prereqs' []: nothing -> table<id: int, name: string> {
$env.__state_prereqs
}

def --env 'write prereqs' [--skipval(-s)]: table<id: int, name: string> -> nothing {
let new = $in
if $skipval {
  $env.__state_prereqs = $new
  return
}
let err = $new | do --env {||
        # TODO: add actual logic checking for impossible situations here
        # ex. no cycles (though maybe this is handled server-side, check later)
        null
      }
if $err != null {
  util print error $err
  return
}
$env.__state_prereqs = $new
}

def --env 'validate prereqs' []: nothing -> oneof<string, nothing> {
read prereqs | do --env {||
        # TODO: add actual logic checking for impossible situations here
        # ex. no cycles (though maybe this is handled server-side, check later)
        null
      }
}

def --env 'read postreqs' []: nothing -> table<id: int, name: string> {
$env.__state_postreqs
}

def --env 'write postreqs' [--skipval(-s)]: table<id: int, name: string> -> nothing {
let new = $in
if $skipval {
  $env.__state_postreqs = $new
  return
}
let err = $new | do --env {||
        # TODO: add actual logic checking for impossible situations here
        # ex. no cycles (though maybe this is handled server-side, check later)
        null
      }
if $err != null {
  util print error $err
  return
}
$env.__state_postreqs = $new
}

def --env 'validate postreqs' []: nothing -> oneof<string, nothing> {
read postreqs | do --env {||
        # TODO: add actual logic checking for impossible situations here
        # ex. no cycles (though maybe this is handled server-side, check later)
        null
      }
}

def --env 'read start' []: nothing -> oneof<datetime, nothing> {
$env.__state_start
}

def --env 'write start' [--skipval(-s)]: oneof<datetime, nothing> -> nothing {
let new = $in
if $skipval {
  $env.__state_start = $new
  return
}
let err = $new | do --env {|| 
if (read start) == null or (read end) == null {
  return
}
let start: datetime = read start
let end: datetime = read end
if $start >= $end {
  'explicit start cannot be >= end'
} }
if $err != null {
  util print error $err
  return
}
$env.__state_start = $new
}

def --env 'validate start' []: nothing -> oneof<string, nothing> {
read start | do --env {|| 
if (read start) == null or (read end) == null {
  return
}
let start: datetime = read start
let end: datetime = read end
if $start >= $end {
  'explicit start cannot be >= end'
} }
}

def --env 'read end' []: nothing -> oneof<datetime, nothing> {
$env.__state_end
}

def --env 'write end' [--skipval(-s)]: oneof<datetime, nothing> -> nothing {
let new = $in
if $skipval {
  $env.__state_end = $new
  return
}
let err = $new | do --env {|| 
if (read start) == null or (read end) == null {
  return
}
let start: datetime = read start
let end: datetime = read end
if $start >= $end {
  'explicit start cannot be >= end'
} }
if $err != null {
  util print error $err
  return
}
$env.__state_end = $new
}

def --env 'validate end' []: nothing -> oneof<string, nothing> {
read end | do --env {|| 
if (read start) == null or (read end) == null {
  return
}
let start: datetime = read start
let end: datetime = read end
if $start >= $end {
  'explicit start cannot be >= end'
} }
}

def --env 'set parent' []: nothing -> nothing {
let new = read parent | do --env {|| 
{
  type: PARENT
  task_id: $params.task_id
}
| api.gen API ListPossibleRelatives
| get entries
| util choose table --header 'Choose parent:'
 }
if $new == null { return }
$new | write parent 
}

def --env 'set start' []: nothing -> nothing {
let new = read start | do --env {|| do --env {|| util choose date } }
if $new == null { return }
$new | write start 
}

def --env 'set end' []: nothing -> nothing {
let new = read end | do --env {|| do --env {|| util choose date } }
if $new == null { return }
$new | write end 
}

def --env 'add prereqs' []: nothing -> nothing {
let orig = read prereqs
let chosen = $orig | do --env {|| {
  type: PREREQ
  task_id: $params.task_id
}
| api.gen API ListPossibleRelatives
| get entries
| util choose table --header 'Choose a PREREQ to add:' }
if $chosen == null { return }
$orig
	| append $chosen
	| write prereqs 
}

def --env 'add postreqs' []: nothing -> nothing {
let orig = read postreqs
let chosen = $orig | do --env {|| {
  type: POSTREQ
  task_id: $params.task_id
}
| api.gen API ListPossibleRelatives
| get entries
| util choose table --header 'Choose a POSTREQ to add:' }
if $chosen == null { return }
$orig
	| append $chosen
	| write postreqs 
}

def --env 'remove prereqs' []: nothing -> nothing {
let orig = read prereqs
let chosen = $orig
	| each {|row|
		($row | do --env {|| $in })
	}
	| util choose table --header 'Remove: Tasks that must be scheduled before this task.'
if $chosen == null { return }
if not (util confirm --prompt $"Are you sure you wish to remove ($chosen.name)?") { return }
$orig
	| where ($it | do --env {|| $in } | get id) != $chosen.id
	| write prereqs 
}

def --env 'remove postreqs' []: nothing -> nothing {
let orig = read postreqs
let chosen = $orig
	| each {|row|
		($row | do --env {|| $in })
	}
	| util choose table --header 'Remove: Tasks that must be scheduled after this task.'
if $chosen == null { return }
if not (util confirm --prompt $"Are you sure you wish to remove ($chosen.name)?") { return }
$orig
	| where ($it | do --env {|| $in } | get id) != $chosen.id
	| write postreqs 
}

def --env 'cancel' [--no-prompt(-y)]: nothing -> nothing {
if not $no_prompt and not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }

null | nav save form output
exit # nu-lint-ignore: exit_only_in_main
}

def --env 'done' []: nothing -> nothing {
let err = read parent | do --env {|| null }
if $err != null {
  util print label 'Parent:'
	util print error $err
  return
}
let err = read prereqs | do --env {||
        # TODO: add actual logic checking for impossible situations here
        # ex. no cycles (though maybe this is handled server-side, check later)
        null
      }
if $err != null {
  util print label 'Prerequisites:'
	util print error $err
  return
}
let err = read postreqs | do --env {||
        # TODO: add actual logic checking for impossible situations here
        # ex. no cycles (though maybe this is handled server-side, check later)
        null
      }
if $err != null {
  util print label 'Postrequisites:'
	util print error $err
  return
}
let err = read start | do --env {|| 
if (read start) == null or (read end) == null {
  return
}
let start: datetime = read start
let end: datetime = read end
if $start >= $end {
  'explicit start cannot be >= end'
} }
if $err != null {
  util print label 'Start:'
	util print error $err
  return
}
let err = read end | do --env {|| 
if (read start) == null or (read end) == null {
  return
}
let start: datetime = read start
let end: datetime = read end
if $start >= $end {
  'explicit start cannot be >= end'
} }
if $err != null {
  util print label 'End:'
	util print error $err
  return
}
{'parent': (read parent)
'prereqs': (read prereqs)
'postreqs': (read postreqs)
'start': (read start)
'end': (read end)} | nav save form output

exit
}

def --env 'status' []: nothing -> nothing {
util print label 'Parent [relationships]'
util print desc 'Parent task'
read parent | do --env {|| match ($in | describe | parse -r `^(?<type>\w+)` | get 0.type) {
'record' => { $in | do {|| table -e | print } }
'nothing' => { $in | do {|| print } }
} } | print
let err = read parent | do --env {|| null }
if $err != null {
	util print error $err
}
print ''
util print label 'Prerequisites [relationships]'
util print desc 'Tasks that must be scheduled before this task.'
read prereqs | do --env {|| table -e | print } | print
let err = read prereqs | do --env {||
        # TODO: add actual logic checking for impossible situations here
        # ex. no cycles (though maybe this is handled server-side, check later)
        null
      }
if $err != null {
	util print error $err
}
print ''
util print label 'Postrequisites [relationships]'
util print desc 'Tasks that must be scheduled after this task.'
read postreqs | do --env {|| table -e | print } | print
let err = read postreqs | do --env {||
        # TODO: add actual logic checking for impossible situations here
        # ex. no cycles (though maybe this is handled server-side, check later)
        null
      }
if $err != null {
	util print error $err
}
print ''
util print label 'Start [explicit_range]'
util print desc 'An explicit time which the task must start after.'
read start | do --env {|| match ($in | describe | parse -r `^(?<type>\w+)` | get 0.type) {
'datetime' => { $in | do {|| util print date $in } }
'nothing' => { $in | do {|| print } }
} } | print
let err = read start | do --env {|| 
if (read start) == null or (read end) == null {
  return
}
let start: datetime = read start
let end: datetime = read end
if $start >= $end {
  'explicit start cannot be >= end'
} }
if $err != null {
	util print error $err
}
print ''
util print label 'End [explicit_range]'
util print desc 'An explicit time which the task must start before.'
read end | do --env {|| match ($in | describe | parse -r `^(?<type>\w+)` | get 0.type) {
'datetime' => { $in | do {|| util print date $in } }
'nothing' => { $in | do {|| print } }
} } | print
let err = read end | do --env {|| 
if (read start) == null or (read end) == null {
  return
}
let start: datetime = read start
let end: datetime = read end
if $start >= $end {
  'explicit start cannot be >= end'
} }
if $err != null {
	util print error $err
}
print ''
}

def --env 'next' []: nothing -> bool {
if (validate parent) != null {
	do --env {|| set parent }
	let err = validate parent
	if $err != null {
		return false
	}
	return (next)
}
if (validate prereqs) != null {
	do --env {|| set prereqs }
	let err = validate prereqs
	if $err != null {
		return false
	}
	return (next)
}
if (validate postreqs) != null {
	do --env {|| set postreqs }
	let err = validate postreqs
	if $err != null {
		return false
	}
	return (next)
}
if (validate start) != null {
	do --env {|| set start }
	let err = validate start
	if $err != null {
		return false
	}
	return (next)
}
if (validate end) != null {
	do --env {|| set end }
	let err = validate end
	if $err != null {
		return false
	}
	return (next)
}
return true
}

def --env 'cmds' []: nothing -> table<group: string, name: string, aliases: string, desc: string> {
[[group name aliases desc];["relationships","read parent","","Get the value of parent."]
["relationships","write parent","","Set the value of parent."]
["relationships","validate parent","","Check if the current value of parent has any errors."]
["relationships","read prereqs","","Get the value of prereqs."]
["relationships","write prereqs","","Set the value of prereqs."]
["relationships","validate prereqs","","Check if the current value of prereqs has any errors."]
["relationships","read postreqs","","Get the value of postreqs."]
["relationships","write postreqs","","Set the value of postreqs."]
["relationships","validate postreqs","","Check if the current value of postreqs has any errors."]
["explicit_range","read start","","Get the value of start."]
["explicit_range","write start","","Set the value of start."]
["explicit_range","validate start","","Check if the current value of start has any errors."]
["explicit_range","read end","","Get the value of end."]
["explicit_range","write end","","Set the value of end."]
["explicit_range","validate end","","Check if the current value of end has any errors."]
["relationships","set parent","","Set parent interactively."]
["explicit_range","set start","","Set start interactively."]
["explicit_range","set end","","Set end interactively."]
["relationships","add prereqs","","Add a value to list prereqs interactively."]
["relationships","add postreqs","","Add a value to list postreqs interactively."]
["relationships","remove prereqs","","Remove a value from list prereqs interactively."]
["relationships","remove postreqs","","Remove a value from list postreqs interactively."]
["control","cancel","c","Abort submission and discard changes."]
["control","done","d","Validate and submit form."]
["control","status","s","Show the current form status."]
["control","next","n","Fill in the next unfilled fields interactively."]]
}

util print section title 'task-optional'
cmds | table -e | print
$env.__state_parent = do --env {|| $params.parent }
$env.__state_prereqs = do --env {|| $params.prereqs }
$env.__state_postreqs = do --env {|| $params.postreqs }
$env.__state_start = do --env {|| $params.start }
$env.__state_end = do --env {|| $params.end }

alias c = cancel
alias d = done
alias s = status
alias n = next