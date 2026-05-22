use lib/api.gen.nu
use lib/util.nu
use forms/gen/index.nu

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) (do $cmd)" }

def "prompt prefix" []: nothing -> string {
	"(scheduler)"
}

def profiles []: nothing -> nothing {
	{
		prompt_prefix: (prompt prefix)
		state: null
	} | index form profiles
}

def --env "switch profile" []: nothing -> bool {
	let profile_list = {} | api.gen API ListProfiles | get entries
	if ($profile_list | is-empty) {
		profiles
		return true
	}

	let profile = $profile_list
		| select id name
		| util choose table --header "Choose profile"
	if $profile == null {
		return false
	}
	$env.profile = $profile.id
	true
}

def --env "new task" []: nothing -> nothing {
	let task_state = {
		prompt_prefix: (prompt prefix)
		state: {
			profile: $env.profile
			payload: null
		}
	} | index form task
	if $task_state == null { return }

	{
		id: null
		profile_id: $env.profile
		state: $task_state
	} | api.gen API SaveTask

	null
}

def --env "progress update" []: nothing -> nothing {
	{
		prompt_prefix: (prompt prefix)
		state: {profile: $env.profile}
	} | index form progress
}

def help []: nothing -> nothing {
	print [[cmd help];
		[profiles             "Manage profiles"]
		['switch profile, sp'  "Switch to a different profile"]
		['new task, nt'        "Create a task"]
		['progress update, pu' "Update task progress"]]
}

if not (switch profile) {
	print exiting!
	exit
}

alias c = exit
alias sp = switch profile
alias nt = new task
alias pu = progress update

help

