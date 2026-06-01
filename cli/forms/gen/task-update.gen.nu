use '../../lib/util.nu'
use '../../lib/proto/apipb/api.gen.nu'
use index.nu

let p: record<prompt_prefix: string, state: record<profile: int>> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state

def --env "returns post process" []: any -> oneof<nothing, record<task_id: int, task_state: record, progress_log: string>> {
    {                                   
        task_id: $env.task              
        task_state: $env.state          
        progress_log: $env.progress_log?
    }                                   
}

def "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(task-update\)"
}

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


def 'fetch last checkpoint' []: nothing -> oneof<datetime, nothing> {
	{profile: $p.state.profile} | api.gen API GetLastCheckpoint | get time?
}

def 'fetch scheduled' []: record -> table {
	api.gen API ListScheduledTasks | get entries
}

def --env 'fetch state' [] {
	if $env.task != null {
		$env.state = {id: $env.task} | api.gen API ReadTask | get state
	}
}

def --env 'pick scheduled' [--timescale(-u): int] {
	let last_ckpt = fetch last checkpoint
	if $last_ckpt == null {
		error make {msg: 'last checkpoint does not exist'}
	}
	$env.task = {
		profile_id: $p.state.profile
		timescale: $timescale
		start: $last_ckpt
		end: (date now)
	} | fetch scheduled | util choose table --header 'Choose a task (scheduled since last checkpoint):' | get id?
	fetch state
}

def --env 'pick task' [--timescale(-u): int, --start(-s): datetime, --end(-e): datetime] {
	# defaults to all task scheduled within 1 wk window of now
	let now = date now
	$env.task = {
		profile_id: $p.state.profile
		timescale: $timescale
		start: ($now - 1wk)
		end: ($now + 1wk)
	} | fetch scheduled | util choose table --header 'Choose a task:' | get id?
	fetch state
}

def 'cmds' [] {
	print [[cmd desc];
		['read dur,rd' 'read task duration']
		['set dur,sd' 'set task duration']
		['edit,e' 'directly edit task']
		['done,d' 'submit']
		['rav,util range shift amount' 'add/subtract a constant amount of time from the time estimate']
		['rap,util range shift percent' 'add/subtract a constant percentage of time from the time estimate']
		['rsf,util range scale' 'scale the time estimates by a factor (ex. 2x)']
		['rsp,util range widen' 'scale the time estimates by an additional percentage (ex. 50% more)']
	]
}

def 'read children entries' [] {
	$in
		| get children
		| flatten
		| group-by id --to-table
		| update items { get 0.name }
		| rename --column {items: name}
}

def --env 'read dur' []: nothing -> record<pes: duration, exp: duration, opt: duration> {
	$env.state.duration_cfg.pert
}

def --env 'set dur' [--id: int]: record<pes: duration, exp: duration, opt: duration> -> nothing {
	let new_value = $in
	if $env.task? == null {
		print 'no task selected'
		return
	}

	let task_state = if $id != null {
		{id: $id} | api.gen API ReadTask | get state
	} else {
		$env.state
	}

	print $task_state

	let children: table<id: int, name: string> = $task_state
		| get children_cfgs
		| read children entries

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
	if $new_state == null {
		return
	}
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
				$prev.duration_cfg.pert | util range format
			} else { 'null' }) -> (if $next.duration_cfg != null {
				$next.duration_cfg.pert | util range format
			} else { 'null' })'
		})
		(if $changed_children { 'changed children' })
		(if $changed_meta { 'changed metadata' })
		(if $changed_timescale { 'changed timescale' })
		(if $changed_constraints { 'changed constraints' })
	] | where $it != null | str join ' & '
}

alias rd = read dur
alias sd = set dur
alias e = edit
alias rav = util range shift amount
alias rap = util range shift percent
alias rsf = util range scale
alias rsp = util range widen

if $env.task? == null {
	let last_ckpt = fetch last checkpoint
	if $last_ckpt != null {
		pick scheduled
	} else {
		print 'run `pick task` to pick a task, you may add additional filters with flags'
		return false
	}
}


