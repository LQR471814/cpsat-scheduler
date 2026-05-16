use lib/state.nu
use lib/util.nu

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) (do $cmd)" }

def "prompt prefix" []: nothing -> string {
	"(scheduler)"
}

def profiles []: nothing -> nothing {
	util exec form ./forms/profiles.gen.nu {
		prompt_prefix: (prompt prefix)
		state: null
	}
}

def "switch profile" []: nothing -> bool {
	let profile_list = state list profiles
	if ($profile_list | is-empty) {
		profiles
		return true
	}
	let profile = $profile_list
		| util choose table
	if $profile == null {
		return false
	}
	$env.profile = $profile.id
	true
}

def "new task" []: nothing -> nothing {
	util exec form ./forms/task/task.gen.nu {
		prompt_prefix: ""
		state: {
			profile: $env.profile
			payload: {}
		}
	}
	null
}

if not (switch profile) {
	exit
}

