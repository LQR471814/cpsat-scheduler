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

let __input: record<prompt_prefix: string, params: oneof<record<pert: oneof<oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, nothing>, deadline: oneof<oneof<nothing, datetime>, nothing>, total_cost: oneof<oneof<nothing, int>, nothing>>, nothing>> = nav get form params

let prompt_prefix: string = $__input.prompt_prefix
let params: oneof<record<pert: oneof<oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, nothing>, deadline: oneof<oneof<nothing, datetime>, nothing>, total_cost: oneof<oneof<nothing, int>, nothing>>, nothing> = $__input.params

let default_prompt_prefix: closure = $env.PROMPT_COMMAND
$env.prompt_prefix = {|| prompt prefix }
$env.PROMPT_COMMAND = do --env {|| $"(prompt prefix) ($in | do $default_prompt_prefix)" }
$env.__state = {}
let params = $params | default {}

def "prompt prefix" []: nothing -> string {
$"($prompt_prefix) \(" + "task-duration" + "\)"
}

def --env "read pert" []: nothing -> oneof<record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>, nothing> {
$env.__state.pert
}

def --env "write pert" [--skipval(-s)]: oneof<record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>, nothing> -> nothing {
let new = $in
if $skipval {
  $env.__state.pert = $new
  return
}
let err = $new | do --env {||
        let rng = $in
        if ($rng | is-empty) {
          return "PERT cannot be unset"
        }
        if $rng.opt > $rng.exp {
          return "PERT optimistic estimate (minimum duration) must be less than its expected estimate (average duration)"
        }
        if $rng.exp > $rng.pes {
          return "PERT expected estimate (average duration) must be less than its pessimistic estimate (maximum duration)"
        }
      }
if $err != null {
  util print error $err
  return
}
$env.__state.pert = $new
}

def --env "validate pert" []: nothing -> oneof<string, nothing> {
read pert | do --env {||
        let rng = $in
        if ($rng | is-empty) {
          return "PERT cannot be unset"
        }
        if $rng.opt > $rng.exp {
          return "PERT optimistic estimate (minimum duration) must be less than its expected estimate (average duration)"
        }
        if $rng.exp > $rng.pes {
          return "PERT expected estimate (average duration) must be less than its pessimistic estimate (maximum duration)"
        }
      }
}

def --env "read deadline" []: nothing -> oneof<datetime, nothing> {
$env.__state.deadline
}

def --env "write deadline" [--skipval(-s)]: oneof<datetime, nothing> -> nothing {
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

def --env "read total_cost" []: nothing -> oneof<int, nothing> {
$env.__state.total_cost
}

def --env "write total_cost" [--skipval(-s)]: oneof<int, nothing> -> nothing {
let new = $in
if $skipval {
  $env.__state.total_cost = $new
  return
}
let err = $new | do --env {||
        if ($in == null) {
          "cost cannot be null"
        }
      }
if $err != null {
  util print error $err
  return
}
$env.__state.total_cost = $new
}

def --env "validate total_cost" []: nothing -> oneof<string, nothing> {
read total_cost | do --env {||
        if ($in == null) {
          "cost cannot be null"
        }
      }
}

def --env "set deadline" []: nothing -> nothing {
let new = read deadline | do --env {|| do --env {|| util choose date } }
if $new == null { return }
$new | write deadline 
}

def --env "set total_cost" []: nothing -> nothing {
let new = read total_cost | do --env {|| do --env {|| util input int "The cost of the task, the optimizer will try to minimize total amount of cost." } }
if $new == null { return }
$new | write total_cost 
}

def --env "set pert" [opt: duration exp: duration pes: duration]: nothing -> nothing {
{opt: $opt, exp: $exp, pes: $pes} | write pert 
}

def --env "cancel" [--no-prompt(-y)]: nothing -> nothing {
if not $no_prompt and not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }

null | nav save form output
exit # nu-lint-ignore: exit_only_in_main
}

def --env "done" []: nothing -> nothing {
let err = read pert | do --env {||
        let rng = $in
        if ($rng | is-empty) {
          return "PERT cannot be unset"
        }
        if $rng.opt > $rng.exp {
          return "PERT optimistic estimate (minimum duration) must be less than its expected estimate (average duration)"
        }
        if $rng.exp > $rng.pes {
          return "PERT expected estimate (average duration) must be less than its pessimistic estimate (maximum duration)"
        }
      }
if $err != null {
  util print label "PERT"
	util print error $err
  return
}
let err = read deadline | do --env {|| null }
if $err != null {
  util print label "Deadline"
	util print error $err
  return
}
let err = read total_cost | do --env {||
        if ($in == null) {
          "cost cannot be null"
        }
      }
if $err != null {
  util print label "Cost"
	util print error $err
  return
}
{"pert": (read pert)
"deadline": (read deadline)
"total_cost": (read total_cost)} | nav save form output

exit
}

def --env "status" []: nothing -> nothing {
util print label "PERT"
util print desc "An estimation of the range of times "
read pert | do --env {|| match ($in | describe | parse --regex `^(?<type>\w+)` | get 0.type) {
"record" => { $in | do {|| table --expand | print } }
"record" => { $in | do {|| table --expand | print } }
"record" => { $in | do {|| table --expand | print } }
"nothing" => { $in | do {|| print } }
} } | print
let err = read pert | do --env {||
        let rng = $in
        if ($rng | is-empty) {
          return "PERT cannot be unset"
        }
        if $rng.opt > $rng.exp {
          return "PERT optimistic estimate (minimum duration) must be less than its expected estimate (average duration)"
        }
        if $rng.exp > $rng.pes {
          return "PERT expected estimate (average duration) must be less than its pessimistic estimate (maximum duration)"
        }
      }
if $err != null {
	util print error $err
}
print ''
util print label "Deadline"
util print desc "The task deadline, after which, cost will apply."
read deadline | do --env {|| match ($in | describe | parse --regex `^(?<type>\w+)` | get 0.type) {
"datetime" => { $in | do {|| util print date $in } }
"nothing" => { $in | do {|| print } }
} } | print
let err = read deadline | do --env {|| null }
if $err != null {
	util print error $err
}
print ''
util print label "Cost"
util print desc "The cost of the task, the optimizer will try to minimize total amount of cost."
read total_cost | do --env {|| match ($in | describe | parse --regex `^(?<type>\w+)` | get 0.type) {
"int" => { $in | do {|| util print number $in } }
"nothing" => { $in | do {|| print } }
} } | print
let err = read total_cost | do --env {||
        if ($in == null) {
          "cost cannot be null"
        }
      }
if $err != null {
	util print error $err
}
print ''
}

def --env "next" []: nothing -> bool {
if (validate total_cost) != null {
	do --env {|| set total_cost }
	let err = validate total_cost
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
if (validate pert) != null {
	do --env {|| print 'use the `set pert` command to set the PERT duration range' }
	let err = validate pert
	if $err != null {
		return false
	}
	return (next)
}
return true
}

def --env "cmds" []: nothing -> table<group: string, name: string, aliases: string, desc: string> {
[[group name aliases desc];["","read pert","","Get the value of pert."]
["","write pert","","Set the value of pert."]
["","validate pert","","Check if the current value of pert has any errors."]
["","read deadline","","Get the value of deadline."]
["","write deadline","","Set the value of deadline."]
["","validate deadline","","Check if the current value of deadline has any errors."]
["","read total_cost","","Get the value of total_cost."]
["","write total_cost","","Set the value of total_cost."]
["","validate total_cost","","Check if the current value of total_cost has any errors."]
["","set deadline","","Set deadline interactively."]
["","set total_cost","","Set total_cost interactively."]
["","set pert","","Set the PERT range of durations."]
["control","cancel","c","Abort submission and discard changes."]
["control","done","d","Validate and submit form."]
["control","status","s","Show the current form status."]
["control","next","n","Fill in the next unfilled fields interactively."]]
}

util print section title "task-duration"
cmds | table --expand | print
$env.__state.pert = do --env {|| $params.pert? }
$env.__state.deadline = do --env {|| $params.deadline? }
$env.__state.total_cost = do --env {|| $params.total_cost? }

alias c = cancel
alias d = done
alias s = status
alias n = next