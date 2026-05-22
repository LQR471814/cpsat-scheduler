use ./lib.nu

let form = {
	name: task-update
	use: (lib form imports)
	params: {type: 'nothing'}
	returns: {
		type: 'record'
		fields: [[key value];
			[task_id {type: int}]
			[task_state {type: record}]
			[progress_log {type: string}]
		]
	}
	closures: {
		returns_post_process: "{
	task_id: $env.task
	task_state: $env.state
	progress_log: $env.progress_log?
}"
	}
	fields: []
	backmatter: "
def --env 'pick scheduled' [--timescale(-u): int] {
	let last_ckpt: oneof<datetime, nothing> = api.gen API GetLastCheckpoint | get time?
	if $last_ckpt == null {
		error make {msg: 'last checkpoint does not exist'}
	}
	$env.task = {
		profile_id: $p.state.profile
		timescale: $timescale
		start: $last_ckpt
		end: (date now | date to-timezone local)
	} | api.gen API ListScheduled | get entries | util choose table --header 'Choose a task (scheduled since last checkpoint):' | get id
}

def --env 'pick task' [--timescale(-u): int, --start(-s): datetime, --end(-e): datetime] {
	# defaults to all task scheduled within 1 wk window of now
	let now = date now | date to-timezone local
	$env.task = {
		profile_id: $p.state.profile
		timescale: $timescale
		start: ($now - 1wk)
		end: ($now + 1wk)
	} | api.gen API ListScheduled | get entries | util choose table --header 'Choose a task:' | get id
}

def --env next []: nothing -> bool {
	if $env.task? == null {
		let last_ckpt: oneof<datetime, nothing> = api.gen API GetLastCheckpoint | get time?
		if $last_ckpt != null {
			pick scheduled
			if not (next) { return false }
		} else {
			print 'run `pick task` to pick a task, you may add additional filters with flags'
			return false
		}
	}
	$env.state = {id: $env.task} | api.gen API ReadTaskRequest | get state
	print [[cmd desc];
		['get dur,gd' 'get task duration']
		['set dur,sd' 'set task duration']
		['edit,e' 'directly edit task']
		['done,d' 'submit']
		['util range *' 'PERT manipulation commands']
	]
	true
}

def 'get children entries' [] {
	$in
		| get children
		| flatten
		| group-by id --to-table
		| update items { get 0.name }
		| rename --column {items: name}
}

def --env 'set dur' [--id: int]: record<pes: duration, exp: duration, opt: duration> -> nothing {
	let new_value = $in
	if $env.task? == null {
		print 'no task selected'
		return
	}

	let task_state = if $id != null {
		{id: $id} | api.gen API ReadTaskRequest
	} else {
		$env.state
	}

	let children: table<id: int, name: string> = $task_state
		| get state.children_cfgs
		| get children entries

	# if leaf task
	if ($children | is-empty) {
		let new_state = $task_state | update duration_cfg $new_value
		update progress log $env.state $new_state
		$env.state = $new_state

		print $'set duration of task `($env.state.name)`'
		return
	}

	# if parent task
	let child = $children | util choose table --header 'Choose a more specific target for time allocation:'
	if $child == null {
		print 'canceled.'
		return
	}

	$new_value | set dur --id $child.id
}

def --env edit [] {
	if $env.task? == null {
		print 'no task selected'
		return
	}
	let new_state = {
		prompt_prefix: (prompt prefix)
		state: {
			profile: $p.state.profile
			payload: {
				task: $env.task
			}
		}
	} | index form task
	update progress log $env.state $new_state
	$env.state = $new_state
}

def --env 'update progress log' [prev: record, next: record]: nothing -> nothing {
	let changed_meta = $next.name != $prev.name or $next.desc != $prev.desc
	let changed_timescale = $next.timescale != $prev.timescale
	let updated_dur = $next.duration_cfg == $prev.duration_cfg
	let changed_children = $next.children_cfgs != $prev.children_cfgs
	let changed_constraints = $next.prereqs != $prev.prereqs or $next.postreqs != $prev.postreqs or $next.parent != $prev.parent or $next.start != $prev.start or $next.end != $prev.end

	$env.progress_log = [
		(if $updated_dur {
			$'changed duration: (if $prev.duration_cfg != null {
				$prev.duration_cfg | util range format
			} else { 'null' }) -> (if $next.duration_cfg != null {
				$next.duration_cfg | util range format
			} else { 'null' })'
		})
		(if $changed_children { 'changed children' })
		(if $changed_meta { 'changed metadata' })
		(if $changed_timescale { 'changed timescale' })
		(if $changed_constraints { 'changed constraints' })
	] | where $it != null | str join ' & '
}

alias gd = get dur
alias sd = set dur
alias e = edit

next
"
}

$form | to json --raw

