use lib/api.gen.nu
use lib/util.nu
use forms/gen/index.nu

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) (do $cmd)" }

def "prompt prefix" []: nothing -> string {
	"(scheduler)"
}

def reschedule []: nothing -> nothing {
	# recompute schedule
	let spinner = util spin start
	job spawn {
		{profile: $env.profile} | api.gen API RecomputeSchedule
		$spinner | util spin stop
	}
	$spinner | util spin show 'Recomputing schedule...'
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

	reschedule
	null
}

def --env "progress update" []: nothing -> nothing {
	{
		prompt_prefix: (prompt prefix)
		state: {profile: $env.profile}
	} | index form progress
	reschedule
}

def --env "print segment tasks" []: datetime -> nothing {
	let time = $in
	util print label "Current segment (±4 hour period)"
	{
		profile_id: $env.profile
		timescale: 16
		start: ($time - 4hr)
		end: ($time + 4hr)
	} | api.gen API ListScheduledTasks | get entries
}

def --env "print date tasks" []: datetime -> nothing {
	let start_of_day = $in | format date %Y-%m-%d | into datetime
	let end_of_day = $in + 1day | format date %Y-%m-%d | into datetime
	util print label "Today's tasks"
	{
		profile_id: $env.profile
		timescale: 96
		start: $start_of_day
		end: $end_of_day
	} | api.gen API ListScheduledTasks | get entries
}

def --env now [] {
	date now | print segment tasks
}

def --env today [] {
	date now | print date tasks
}

def --env tomorrow [] {
	(date now) + 1day | print date tasks
}

def --env yesterday [] {
	(date now) - 1day | print date tasks
}

def help []: nothing -> nothing {
	print [[cmd help];
		[profiles              "Manage profiles"]
		['switch profile, sp'  "Switch to a different profile"]
		['new task, nt'        "Create a task"]
		['progress update, pu' "Update task progress"]
		['today, td'           "Show today's tasks"]
		['tomorrow, tm'        "Show tomorrow's tasks"]
		['yesterday, ys'       "Show yesterday's tasks"]
		['reschedule, re'      "Reschedule tasks"]
	]
}

if not (switch profile) {
	print exiting!
	exit
}

alias c = exit
alias d = exit
alias sp = switch profile
alias nt = new task
alias pu = progress update
alias td = today
alias tm = tomorrow
alias ys = yesterday
alias re = reschedule

help

