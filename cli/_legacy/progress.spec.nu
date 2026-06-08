use ./lib.nu

let form = {
  name: progress
  use: (lib form imports)
  params: {
    type: record
    fields: [
      [key value];
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
	$env.state ++= [$updated]
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
"
}

$form | to json --raw
