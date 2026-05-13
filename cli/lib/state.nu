const API_SERVICE_PATH = "API"
const SOCKET_PATH = "/tmp/cpsat-scheduler.api.sock"

def req [method: string]: any -> any {
	^buf curl -d ($in | to json) --unix-socket $SOCKET_PATH --protocol grpc --http2-prior-knowledge --schema ../proto $"http://localhost/($API_SERVICE_PATH)/($method)"
		| from json
}

export def "list profiles" []: nothing -> table<id: int, name: string> {
	{} | req ListProfiles | get entries
}

export def "read task" [id: int]: nothing -> record<state: record<name: string, desc: string, timescale: int, duration_cfg: record<pes: int, exp: int, opt: int, deadline: record<seconds: int, nanos: int>, total_cost: int>, children_cfgs: list<record<desc: string, deadline: record<seconds: int, nanos: int>, exp_cost: int, children: list<int>>>, prereqs: list<int>, postreqs: list<int>, parent: int, start: record<seconds: int, nanos: int>, end: record<seconds: int, nanos: int>>> {
	{id: $id} | req ReadTask
}

export def "save task" [
	profile_id: int
	state: record<name: string, desc: string, timescale: int, duration_cfg: record<pes: int, exp: int, opt: int, deadline: record<seconds: int, nanos: int>, total_cost: int>, children_cfgs: list<record<desc: string, deadline: record<seconds: int, nanos: int>, exp_cost: int, children: list<int>>>, prereqs: list<int>, postreqs: list<int>, parent: int, start: record<seconds: int, nanos: int>, end: record<seconds: int, nanos: int>>
	--id: int
]: nothing -> record {
	{
		id: $id
		profile_id: $profile_id
		state: $state
	} | req SaveTask
}

export def "delete task" [id: int]: nothing -> record {
	{id: $id} | req DeleteTask
}

export def "list scheduled tasks" [
	profile_id: int
	timescale: int
	start: record<seconds: int, nanos: int>
	end: record<seconds: int, nanos: int>
]: nothing -> table<id: int, name: string> {
	{
		profile_id: $profile_id
		timescale: $timescale
		start: $start
		end: $end
	} | req ListScheduledTasks | get entries
}

export def "list possible relatives" [
	type: string # PARENT | CHILD | PREREQ | POSTREQ
	task_id: int
]: nothing -> table<id: int, name: string> {
	{
		type: $type
		task_id: $task_id
	} | req ListPossibleRelatives | get entries
}

export def "progress update" [
	target_task_id: int
	start: record<seconds: int, nanos: int>
	end: record<seconds: int, nanos: int>
]: nothing -> record {
	{
		target_task_id: $target_task_id
		start: $start
		end: $end
	} | req ProgressUpdate
}
