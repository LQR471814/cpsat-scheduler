const API_SERVICE_PATH = "API"
const SOCKET_PATH = "/tmp/cpsat-scheduler.api.sock"

def req [method: string]: any -> any {
	^buf curl -d ($in | to json) --unix-socket $SOCKET_PATH --protocol grpc --http2-prior-knowledge --schema ../proto $"http://localhost/($API_SERVICE_PATH)/($method)"
		| from json
}

def "list profiles" []: nothing -> any {
	{} | req ListProfiles
}

def "read task" [
	id: int
]: nothing -> any {
	{
		id: $id
	} | req ReadTask
}

def "save task" [
	profile_id: int
	state: record
	--id: int
]: nothing -> any {
	{
		id: $id
		profile_id: $profile_id
		state: $state
	} | req SaveTask
}

def "delete task" [
	id: int
]: nothing -> any {
	{
		id: $id
	} | req DeleteTask
}

def "list scheduled tasks" [
	profile_id: int
	timescale: int
	start: record
	end: record
]: nothing -> any {
	{
		profile_id: $profile_id
		timescale: $timescale
		start: $start
		end: $end
	} | req ListScheduledTasks
}

def "list possible relatives" [
	type: string
	task_id: int
]: nothing -> any {
	{
		type: $type
		task_id: $task_id
	} | req ListPossibleRelatives
}

def "progress update" [
	target_task_id: int
	start: record
	end: record
]: nothing -> any {
	{
		target_task_id: $target_task_id
		start: $start
		end: $end
	} | req ProgressUpdate
}
