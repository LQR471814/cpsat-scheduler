use '../../lib/util.nu'
use '../../lib/proto/apipb/api.gen.nu'
use index.nu

let p: record<prompt_prefix: string, state: record<profile: int>> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state

def --env "returns post process" []: any -> nothing {
    run updates
}

def "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(progress\)"
}

def --env submit []: nothing -> nothing {
    next                                                     
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


let profile = $p.state.profile
let time = date now

$env.state = []

def --env desc [] {
	$env.desc = util input multiline Description... | default ''
}

def --env 'add task' [] {
	let updated: record<task_id: int, task_state: record, progress_log: string> = {
		prompt_prefix: (prompt prefix)
		state: {
			profile: $p.state.profile
		}
	} | index form task-update
	if $updated == null { return }
	$env.state ++= $updated
}

def --env 'run updates' []: nothing -> nothing {
	if ($env.state | is-empty) { return }

	let desc = $env.desc? | default ''

	let updates = $env.state
		| select task_id progress_log
		| rename task desc

	# add progress log entry
	{
		profile: $profile
		time: $time
		desc: $desc
		updates: $updates
	} | api.gen API ProgressUpdate

	# save tasks
	$env.state
		| each {
			{
				id: $in.task_id
				profile_id: $profile
				state: $in.task_state
			} | api.gen API SaveTask
		}

	null
}

desc
add task


