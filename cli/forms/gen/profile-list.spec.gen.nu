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

let __input: record<prompt_prefix: string, params: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>>>> = nav get form params

let prompt_prefix: string = $__input.prompt_prefix
let params: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>>> = $__input.params

let default_prompt_prefix: closure = $env.PROMPT_COMMAND
$env.prompt_prefix = {|| prompt prefix }
$env.PROMPT_COMMAND = do --env {|| $"(prompt prefix) ($in | do $default_prompt_prefix)" }


def 'prompt prefix' []: nothing -> string {
$"($prompt_prefix) \(profile-list\)"
}

def --env 'read profile' []: nothing -> list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>>> {
$env.__state_profile
}

def --env 'write profile' [--skipval(-s)]: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>>> -> nothing {
let new = $in
if $skipval {
  $env.__state_profile = $new
  return
}
let err = $new | do --env {||
        if ($in | is-empty) {
          "you must have at least one profile created"
        }
      }
if $err != null {
  util print error $err
  return
}
$env.__state_profile = $new
}

def --env 'validate profile' []: nothing -> oneof<string, nothing> {
read profile | do --env {||
        if ($in | is-empty) {
          "you must have at least one profile created"
        }
      }
}

def --env 'add profile' [name: string atomic_timescale: duration universe_start: datetime --pert_choices: int]: nothing -> nothing {
read profile | append {
	id: null
	name: $name
	atomic_timescale: $atomic_timescale
	universe_start: $universe_start
	gen_pert_choices: $pert_choices
} | write profile 
}

def --env 'remove profile' []: nothing -> nothing {
let orig = read profile
let chosen = $orig
	| each {|row|
		($row | do --env {||
          # @type apigen.Profile
          let profile: record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>> = $in
          $profile | select id name
        })
	}
	| util choose table --header 'Remove: List of existing profiles.'
if $chosen == null { return }
if not (util confirm --prompt $"Are you sure you wish to remove ($chosen.name)?") { return }
$orig
	| where ($it | do --env {||
          # @type apigen.Profile
          let profile: record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>> = $in
          $profile | select id name
        } | get id) != $chosen.id
	| write profile 
}

def --env 'edit profile' []: nothing -> nothing {
let orig = read profile
	| each {|row|
		{
			row: $row
			entry: ($row | do --env {||
          # @type apigen.Profile
          let profile: record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>> = $in
          $profile | select id name
        })
		}
	}

let chosen = $orig
	| get entry
	| util choose table --header 'Edit: List of existing profiles.'
if $chosen == null { return }

let new_row = $orig
	| where entry == $chosen
	| get row
	| do --env {||
          index form profile
        }

if $new_row == null { return }

$orig
	| each {|row|
		if $in.entry == $chosen { $new_row } else { $row }
	}
	| write profile 
}

def --env 'cancel' [--no-prompt(-y)]: nothing -> nothing {
if not $no_prompt and not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }

null | nav save form output
exit # nu-lint-ignore: exit_only_in_main
}

def --env 'done' []: nothing -> nothing {
let err = read profile | do --env {||
        if ($in | is-empty) {
          "you must have at least one profile created"
        }
      }
if $err != null {
  util print label 'Profiles:'
	util print error $err
  return
}
do --env {|| read profile } | nav save form output

exit
}

def --env 'status' []: nothing -> nothing {
util print label 'Profiles [field]'
util print desc 'List of existing profiles.'
read profile | do --env {|| table -e | print } | print
let err = read profile | do --env {||
        if ($in | is-empty) {
          "you must have at least one profile created"
        }
      }
if $err != null {
	util print error $err
}
print ''
}

def --env 'next' []: nothing -> bool {
if (validate profile) != null {
	do --env {||
        print "use the 'add profile' command to a profile"
      }
	let err = validate profile
	if $err != null {
		return false
	}
	return (next)
}
return true
}

def --env 'cmds' []: nothing -> table<group: string, name: string, aliases: string, desc: string> {
[[group name aliases desc];["field","read profile","","Get the value of profile."]
["field","write profile","","Set the value of profile."]
["field","validate profile","","Check if the current value of profile has any errors."]
["field","add profile","ap","add a new profile"]
["field","remove profile","","Remove a value from list profile interactively."]
["field","edit profile","","Choose a value of profile to edit."]
["control","cancel","c","Abort submission and discard changes."]
["control","done","d","Validate and submit form."]
["control","status","s","Show the current form status."]
["control","next","n","Fill in the next unfilled fields interactively."]]
}

util print section title 'profile-list'
cmds | table -e | print
$env.__state_profile = do --env {|| $params }

alias ap = add profile
alias c = cancel
alias d = done
alias s = status
alias n = next