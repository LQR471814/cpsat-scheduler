use '../../lib/util.nu'
use '../../lib/proto/apipb/api.gen.nu'
use index.nu

let p: record<prompt_prefix: string, state: record<task: oneof<int, nothing>, cfg: oneof<record<pert: record<opt: duration, exp: duration, pes: duration>, deadline: oneof<datetime, nothing>, total_cost: oneof<int, nothing>>, nothing>>> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state | params post process

def --env "params post process" []: record<task: oneof<int, nothing>, cfg: oneof<record<pert: record<opt: duration, exp: duration, pes: duration>, deadline: oneof<datetime, nothing>, total_cost: oneof<int, nothing>>, nothing>> -> any {
  update cfg {
    default {
      pert: {
        opt: null
        exp: null
        pes: null
      }
      deadline: null
    }
  }
}

def --env "returns post process" []: any -> oneof<record<pert: record<opt: duration, exp: duration, pes: duration>, deadline: oneof<datetime, nothing>, total_cost: oneof<int, nothing>>, nothing> {
  get cfg
}

def "prompt prefix" []: nothing -> string {
  $"($p.prompt_prefix) \(duration-config\)"
}

def --env "read pert" []: nothing -> record<opt: duration, exp: duration, pes: duration> {
  $env.state.cfg.pert
}

def --env "set pert" []: oneof<record<opt: duration, exp: duration, pes: duration>, nothing> -> nothing {
  $env.state.cfg.pert = $in
}

def --env "validate pert" []: oneof<record<opt: duration, exp: duration, pes: duration>, nothing> -> bool {
  $env.state.cfg.pert.opt != null and $env.state.cfg.pert.exp != null and $env.state.cfg.pert.pes != null
}

def --env pert [opt: duration exp: duration pes: duration]: nothing -> nothing {
  {opt: $opt exp: $exp pes: $pes} | set pert
}

def --env "unset pert" []: nothing -> nothing {
  null | set pert
}

def --env "read deadline" []: nothing -> oneof<datetime, nothing> {
  $env.state.cfg.deadline
}

def --env "set deadline" []: oneof<oneof<datetime, nothing>, nothing> -> nothing {
  $env.state.cfg.deadline = $in
}

def --env deadline []: nothing -> nothing {
  let results = util choose date
  if $results != null { $results | set deadline }
}

def --env "unset deadline" []: nothing -> nothing {
  null | set deadline
}

def --env "read cost" []: nothing -> int {
  $env.state.cfg.total_cost
}

def --env "set cost" []: oneof<int, nothing> -> nothing {
  $env.state.cfg.total_cost = $in
}

def --env "validate cost" []: oneof<int, nothing> -> bool {
  $env.state.cfg.total_cost != null
}

def --env cost []: nothing -> nothing {
  let results = util input int 'Expected cost...'
  if $results != null { $results | set cost }
}

def --env "unset cost" []: nothing -> nothing {
  null | set cost
}

def --env status []: nothing -> nothing {
  util print section title 'Form: duration-config'
  util print label 'PERT (time estimates)'
  print ($env.state.cfg.pert)
  print ""
  util print label 'Deadline'
  util print date ($env.state.cfg.deadline)
  print ""
  util print label 'Expected cost under minimum time investment'
  print ($env.state.cfg.total_cost)
  print ""
}

alias s = status
def --env next []: nothing -> bool {
  # nu-lint-ignore: print_and_return_data                                
  if not ($env.state.cfg.pert | validate pert) {
    print "set pert with 'set pert'"
    return false
  }
  if not ($env.state.cfg.total_cost | validate cost) {
    cost
    if not ($env.state.cfg.total_cost | validate cost) { return false }
    return (next)
  }
  true
}

alias n = next
def cmds []: nothing -> nothing {
  print [
    [group cmd desc];
    [common "status, s" "Show form status."]
    [null "next, n" "Fill in next unfilled field."]
    [null "submit, done, d" "Submit form."]
    [null "cancel, c" "Abort form."]
    ["pert" 'pert' 'Set PERT (time estimates) via nushell command.']
    [null 'read pert' 'Get PERT (time estimates) via nushell command.']
    ["deadline" 'deadline' 'Interactively set Deadline.']
    [null 'write deadline' 'Set Deadline via nushell command.']
    [null 'read deadline' 'Get Deadline via nushell command.']
    ["cost" 'cost' 'Interactively set Expected cost under minimum time investment.']
    [null 'write cost' 'Set Expected cost under minimum time investment via nushell command.']
    [null 'read cost' 'Get Expected cost under minimum time investment via nushell command.']
  ]
}

alias h = help
def --env submit []: nothing -> nothing {
  $env.state | returns post process | util save form output
  exit # nu-lint-ignore: exit_only_in_main                 
}

def --env cancel []: nothing -> nothing {
  if not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }
  null | util save form output
  exit # nu-lint-ignore: exit_only_in_main                                                               
}

alias done = submit
alias d = submit
alias c = cancel

status
help
