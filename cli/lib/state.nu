const API_SERVICE_PATH = "API"
const SOCKET_PATH = "/tmp/cpsat-scheduler.api.sock"

const self_path = path self

export def req [method: string]: any -> any {
    let schema_path = $self_path | path dirname | path join ../../proto
	$in
        | to json --raw
        | buf curl -d @- --unix-socket $SOCKET_PATH --protocol grpc --http2-prior-knowledge --schema $schema_path $"http://localhost/($API_SERVICE_PATH)/($method)"
		| from json
}

export def "create profile" [name: string, atomic_timescale: string, universe_start: string, gen_pert_choices: int]: nothing -> record {
	{
		name: $name
		atomic_timescale: $atomic_timescale
		universe_start: $universe_start
		gen_pert_choices: $gen_pert_choices
	} | req CreateProfile
}

export def "list profiles" []: nothing -> table<id: int, name: string, atomic_timescale: string, universe_start: string, gen_pert_choices: oneof<int, nothing>> {
	{}
		| req ListProfiles
		| get entries? | default []
		| update id? { into int }
}

export def "remove profile" [id: int]: nothing -> record {
	{id: $id} | req RemoveProfile
}

export def "read task" [id: int]: nothing -> record<state: record<name: string, desc: string, timescale: int, duration_cfg: oneof<record<pert: record<pes: string, exp: string, opt: string>, deadline: oneof<string, nothing>, total_cost: int>, nothing>, children_cfgs: list<record<desc: string, deadline: oneof<string, nothing>, exp_cost: int, children: list<record<id: int, name: string>>>>, prereqs: list<record<id: int, name: string>>, postreqs: list<record<id: int, name: string>>, parent: oneof<record<id: int, name: string>, nothing>, start: oneof<string, nothing>, end: oneof<string, nothing>>> {
	{id: $id}
		| req ReadTask
		| update state.parent.id { into int }
		| update state.prereqs.id { into int }
		| update state.postreqs.id { into int }
		| update state.children.id { into int }
}

export def "save task" [profile_id: int, state: record<name: string, desc: string, timescale: int, duration_cfg: oneof<record<pert: record<pes: string, exp: string, opt: string>, deadline: oneof<string, nothing>, total_cost: int>, nothing>, children_cfgs: list<record<desc: string, deadline: oneof<string, nothing>, exp_cost: int, children: list<record<id: int, name: string>>>>, prereqs: list<record<id: int, name: string>>, postreqs: list<record<id: int, name: string>>, parent: oneof<record<id: int, name: string>, nothing>, start: oneof<string, nothing>, end: oneof<string, nothing>>, --id: oneof<int, nothing>]: nothing -> record<id: int> {
	{
		id: $id
		profile_id: $profile_id
		state: $state
	} | req SaveTask | update id { into int } # id is string because of JS precision limits (cannot handle int64/uint64)
}

export def "delete task" [id: int]: nothing -> record {
	{id: $id} | req DeleteTask
}

export def "list scheduled tasks" [profile_id: int, timescale: int, start: string, end: string]: nothing -> table<id: int, name: string> {
	{
		profile_id: $profile_id
		timescale: $timescale
		start: $start
		end: $end
	} | req ListScheduledTasks | get entries? | default [] | update id? { into int }
}

export def "list possible relatives" [type: string, task_id: int]: nothing -> table<id: int, name: string> {
	{
		type: $type
		task_id: $task_id
	} | req ListPossibleRelatives | get entries? | default [] | update id? { into int }
}

export def "progress update" [target_task_id: int, start: string, end: string]: nothing -> record {
	{
		target_task_id: $target_task_id
		start: $start
		end: $end
	} | req ProgressUpdate
}
