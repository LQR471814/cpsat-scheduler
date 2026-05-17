use ../lib.nu # nu-lint-ignore: dont_mix_different_effects

let parent_type = lib type entry record
let ts_type = lib type proto timestamp
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
	frontmatter: null
	params: $state_type
	returns: $state_type
	closures: {
		param_post_process: "update start { util from proto time }
	| update end { util from proto time }"
		returns_post_process: "update start { util to proto time }
	| update end { util to proto time }"
	}
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
					set: "$env.state.parent = state list possible relatives PARENT $p.state.id | util choose table --header 'Choose parent'"
				}
			}
		}
		{
			name: start
			display_name: "Must start after"
			type: $ts_type
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
			type: $ts_type
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
					add: "let chosen = state list possible relatives PREREQ $p.state.id | util choose table --header 'Add a task as a prerequisite:'
if $chosen == null { return }
$env.state.prereqs ++= $chosen"
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
					add: "let chosen = state list possible relatives POSTREQ $p.state.id | util choose table --header 'Add a task as a postrequisite:'
if $chosen == null { return }
$env.state.postreqs ++= $chosen"
				}
			}
		}
	]
}

const self_path = path self
$form | lib gen form $self_path
