use ../lib.nu # nu-lint-ignore: dont_mix_different_effects

let parent_type = lib type entry record
let ts_type = {type: datetime}
let req_type = lib type entry table

let state_type = {
	type: record
	fields: [[key, value];
		[id       ({type: int} | lib type optional)]
		[parent   ($parent_type | lib type optional)]
		[start    ($ts_type | lib type optional)]
		[end      ($ts_type | lib type optional)]
		[prereqs  $req_type]
		[postreqs $req_type]
	]
}

let form = {
	name: optional-fields
	use: (lib form imports)
	frontmatter: null
	params: $state_type
	returns: $state_type
	closures: {}
	fields: [
		{
			name: parent
			display_name: Parent
			type: $parent_type
			closure_bodies: {
				getter: "$env.state.parent"
				setter: "$env.state.parent = $in"
			}
			atomic: {
				closure_bodies: {
					set: "$env.state.parent = {
	type: PARENT
	task_id: $p.state.id
} | api.gen API ListPossibleRelatives | get entries | util choose table --header 'Choose parent'"
				}
			}
		}
		{
			name: start
			display_name: "Must start after"
			type: {type: datetime}
			closure_bodies: {
				validate: "if $env.state.start != null and $env.state.end != null {
	$env.state.start < $env.state.end
} else { true }"
				getter: "$env.state.start"
				setter: "$env.state.start = $in"
			}
			atomic: {
				closure_bodies: {
					set: "$env.state.start = util choose date"
				}
			}
		}
		{
			name: end
			display_name: "Must end before"
			type: {type: datetime}
			closure_bodies: {
				validate: "if $env.state.start != null and $env.state.end != null {
	$env.state.start < $env.state.end
} else { true }"
				getter: "$env.state.end"
				setter: "$env.state.end = $in"
			}
			atomic: {
				closure_bodies: {
					set: "$env.state.end = util choose date"
				}
			}
		}
		{
			name: prereqs
			display_name: Prerequisites
			type: $req_type
			closure_bodies: {
				display_value: "$in.name"
				getter: "$env.state.prereqs"
				setter: "$env.state.prereqs = $in"
			}
			list: {
				closure_bodies: {
					add: "let chosen = {type: PREREQ, task_id: $p.state.id} | api.gen API ListPossibleRelatives | get entries | util choose table --header 'Add a task as a prerequisite:'
if $chosen == null { return }
$env.state.prereqs ++= [$chosen]"
				}
			}
		}
		{
			name: postreqs
			display_name: Postrequisites
			type: $req_type
			closure_bodies: {
				display_value: "$in.name"
				getter: "$env.state.postreqs"
				setter: "$env.state.postreqs = $in"
			}
			list: {
				closure_bodies: {
					add: "let chosen = {type: POSTREQ, task_id: $p.state.id} | api.gen API ListPossibleRelatives | get entries | util choose table --header 'Add a task as a postrequisite:'
if $chosen == null { return }
$env.state.postreqs ++= [$chosen]"
				}
			}
		}
	]
}

$form | to json --raw
