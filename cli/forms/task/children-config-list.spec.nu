use ../lib.nu # nu-lint-ignore: dont_mix_different_effects

let desc_type = {type: string}
let deadline_type = lib type proto timestamp
let exp_cost_type = {type: int}
let children_type = lib type entry table

let state_type = {
	type: record
	fields: [[key, value];
		[task     {type: int}]
		[desc     ($desc_type | lib type optional)]
		[deadline ($deadline_type | lib type optional)]
		[exp_cost ($exp_cost_type | lib type optional)]
		[children $children_type]
	]
}

let form = {
	name: children-config-list
	frontmatter: null
	params: $state_type
	returns: $state_type
	closures: {
		returns_post_process: "reject task"
	}
	fields: [
		{
			name: desc
			display_name: Description
			type: $desc_type
			closure_bodies: {
				key_access: "$env.state.desc"
			}
			atomic: {
				closure_bodies: {
					set: "$env.state.desc = util input multiline Description..."
				}
			}
		}
		{
			name: exp_cost
			display_name: "Expected cost"
			type: $exp_cost_type
			closure_bodies: {
				key_access: "$env.state.exp_cost"
				validate: "$env.state.exp_cost != null"
			}
			atomic: {
				closure_bodies: {
					set: "$env.state.exp_cost = util input int 'Cost... (integer)'"
				}
			}
		}
		{
			name: deadline
			display_name: Deadline
			type: $deadline_type
			closure_bodies: {
				key_access: "$env.state.deadline"
				validate: "$env.state.deadline != null"
			}
			atomic: {
				closure_bodies: {
					set: "$env.state.deadline = util choose date"
				}
			}
		}
		{
			name: children
			display_name: Children
			type: $children_type
			closure_bodies: {
				key_access: "$env.state.children"
				validate: "$env.state.children | is-not-empty"
			}
			list: {
				closure_bodies: {
					add: "let child = state list possible relatives CHILD $p.task | util choose table --header 'Choose child to add:'
if $child == null { return }
$env.state.children ++= $child"
				}
			}
		}
	]
	backmatter: status
}

const self_path = path self
$form | lib gen form $self_path
