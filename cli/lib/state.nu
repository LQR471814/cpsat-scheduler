const API_SERVICE_PATH = "API"
const SOCKET_PATH = "/tmp/cpsat-scheduler.api.sock"

const self_path = path self

export def req [method: string]: any -> any {
    let schema_path = $self_path | path dirname | path join ../../proto
    print ($in | to json --raw)
	$in
        | to json --raw
        | buf curl -d @- --unix-socket $SOCKET_PATH --protocol grpc --http2-prior-knowledge --schema $schema_path $"http://localhost/($API_SERVICE_PATH)/($method)" -v
		| from json
}

export def "create profile" [name: string, atomic_timescale: record<seconds: int, nanos: int>, universe_start: record<seconds: int, nanos: int>, gen_pert_choices: int]: nothing -> record {
	{
		name: $name
		atomic_timescale: $atomic_timescale
		universe_start: $universe_start
		gen_pert_choices: $gen_pert_choices
	} | req CreateProfile
}

export def "list profiles" []: nothing -> table<id: int, name: string, atomic_timescale: record<seconds: int, nanos: int>, universe_start: record<seconds: int, nanos: int>, gen_pert_choices: int> {
	{} | req ListProfiles | get entries
}

export def "remove profile" [id: int]: nothing -> record {
	{id: $id} | req RemoveProfile
}

export def "read task" [id: int]: nothing -> record<state: record<name: string, desc: string, timescale: int, duration_cfg: record<pert: record<pes: record<seconds: int, nanos: int>, exp: record<seconds: int, nanos: int>, opt: record<seconds: int, nanos: int>>, deadline: record<seconds: int, nanos: int>, total_cost: int>, children_cfgs: list<record<desc: string, deadline: record<seconds: int, nanos: int>, exp_cost: int, children: list<record<id: int, name: string>>>>, prereqs: list<record<id: int, name: string>>, postreqs: list<record<id: int, name: string>>, parent: record<id: int, name: string>, start: record<seconds: int, nanos: int>, end: record<seconds: int, nanos: int>>> {
	{id: $id} | req ReadTask
}

export def "save task" [profile_id: int, state: record<name: string, desc: string, timescale: int, duration_cfg: record<pert: record<pes: record<seconds: int, nanos: int>, exp: record<seconds: int, nanos: int>, opt: record<seconds: int, nanos: int>>, deadline: record<seconds: int, nanos: int>, total_cost: int>, children_cfgs: list<record<desc: string, deadline: record<seconds: int, nanos: int>, exp_cost: int, children: list<record<id: int, name: string>>>>, prereqs: list<record<id: int, name: string>>, postreqs: list<record<id: int, name: string>>, parent: record<id: int, name: string>, start: record<seconds: int, nanos: int>, end: record<seconds: int, nanos: int>>, --id: int]: nothing -> record<id: int> {
	{
		id: $id
		profile_id: $profile_id
		state: $state
	} | req SaveTask
}

export def "delete task" [id: int]: nothing -> record {
	{id: $id} | req DeleteTask
}

export def "list scheduled tasks" [profile_id: int, timescale: int, start: record<seconds: int, nanos: int>, end: record<seconds: int, nanos: int>]: nothing -> table<id: int, name: string> {
	{
		profile_id: $profile_id
		timescale: $timescale
		start: $start
		end: $end
	} | req ListScheduledTasks | get entries
}

export def "list possible relatives" [type: string, task_id: int]: nothing -> table<id: int, name: string> {
	{
		type: $type
		task_id: $task_id
	} | req ListPossibleRelatives | get entries
}

export def "progress update" [target_task_id: int, start: record<seconds: int, nanos: int>, end: record<seconds: int, nanos: int>]: nothing -> record {
	{
		target_task_id: $target_task_id
		start: $start
		end: $end
	} | req ProgressUpdate
}

# {} | req ListProfiles | print

create profile "Default" {seconds: (15min // 1sec), nanos: 0} {seconds: (((date now) - (0 | into datetime)) // 1sec), nanos: 0} 3
