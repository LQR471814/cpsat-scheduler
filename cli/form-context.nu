const DURATION_TYPE = "duration"
const CHILDREN_TYPE = "children"

let prompt_prefix = $env.prompt_prefix

# let parent_id = $env.parent_id
# let prereqs = $env.prereqs

let cmd = $env.PROMPT_COMMAND
$env.PROMPT_COMMAND = {||
	$"($prompt_prefix) \(form\) ($cmd)"
}

def status [] {

}

def next []: nothing -> nothing {
	if ($env.name? | is-empty) {
		name
	}
	if ($env.unit? | is-empty) {
		unit
	}
	if ($env.type? | is-empty) {
		type
	}
	match $env.type {
	$DURATION_TYPE => {
		if ($env.deadline? | is-not-empty) and ($env.dur_cost? | is-empty) {
			cost
		}
		if ($env.dur_pert? | is-empty) {
			pert
		}
	}
	$CHILDREN_TYPE => {
	}
	}
}

def name [] {
	$env.name = ^gum input --placeholder Name... --prompt ""
	if $env.name == "not submitted" {
		$env.name = ""
	}
}

def desc [] {
	$env.desc = ^gum write --placeholder Description...
	if $env.desc == "not submitted" {
		$env.desc = ""
	}
}

def unit [] {
	let timescales: list<string> = [
		day
		week
		"2 weeks"
	]

	const HEADER_TEXT = "Timescale unit:"
	$env.unit = ^gum choose --header $HEADER_TEXT ...$timescales
}

def deadline [--date(-d): datetime] {
	if $date != null {
		$env.deadline = $date
		return
	}
	$env.deadline = ^datepicker -y -f %Y-%m-%d -d | into datetime
}

def type [] {
	let types: list<string> = [
		$DURATION_TYPE
		$CHILDREN_TYPE
	]
	const HEADER_TEXT = "Task type:"
	$env.type = ^gum choose --header $HEADER_TEXT ...$types
}

def cost [--value(-v): int]: nothing -> nothing {
	if $value != null {
		$env.cost = $value
		return
	}
	if $env.type? != $DURATION_TYPE {
		print --stderr "note: task was automatically changed to duration type"
		$env.type = $DURATION_TYPE
	}
	if ($env.deadline? | is-empty) {
		deadline
	}
	$env.dur_cost = ^gum --placeholder "Cost... (integer)" --prompt "" | into int
}

def pert [...values: duration]: nothing -> nothing {
	if $env.type? != $DURATION_TYPE {
		print --stderr "note: task was automatically changed to duration type"
		$env.type = $DURATION_TYPE
	}
	if ($values | length) != 3 {
		error make {
			msg: "must specify 3 arguments: <optimistic> <expected> <pessimistic>"
		}
	}
	$env.dur_pert = $values
}

def "choose task" [] {
}

