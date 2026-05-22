use ./lib.nu

let form = {
	name: progress
	use: (lib form imports)
	params: {
		type: record
		fields: [[key value];
			[profile {type: int}]
		]
	}
	returns: {type: 'nothing'}
	closures: {
		returns_post_process: "run updates"
	}
	fields: []
	backmatter: "
let profile = $p.state.profile
let time = date now | date to-timezone local

$env.state = []

def --env desc [] {
	$env.desc = util input multiline Description...
}

def --env 'add task' [] {
	let updated: record<task_id: int, task_state: record, progress_log: string> = {
		prompt_prefix: (prompt prefix)
		state: null
	} | index form task-update
	$env.state ++= $updated
}

def --env next []: nothing -> bool {
	if $env.desc? == null {
		desc
		if not (next) { return false }
	}
	add task
	if not (next) { return false }
}

def --env 'run updates' []: nothing -> nothing {
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

	# recompute schedule
	let spinner = util spin start
	job spawn {
		{profile: $profile} | api.gen API RecomputeSchedule
		$spinner | util spin stop
	}
	$spinner | util spin show 'Recomputing schedule...'

	null
}
"
}

$form | to json --raw

