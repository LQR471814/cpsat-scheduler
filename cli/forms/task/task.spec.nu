use ../lib.nu

const script_path = path self | path dirname # nu-lint-ignore: dont_mix_different_effects

let state = {
	type: record,
	fields: [[key, value];
		[task    ({type: int} | lib type optional)]
		[profile {type: int}]
	]
}

let form = {
	name: task
	params: $state
	returns: $state
	closures: {}
	fields: [
		{
			name: task
			display_name: Task
			type: {type: string}
			closure_bodies: {
				key_access: "$env.state.name"
			}
			atomic: {
				closure_bodies: {
					set: "$env.state.name = util input text Name..."
				}
			}
		}
		{
			name: desc
			display_name: Desc
			type: {type: string}
			closure_bodies: {
				validate: "$env.state.desc | is-not-empty"
				key_access: "$env.state.desc"
			}
			atomic: {
				closure_bodies: {
					set: "$env.state.desc = util input text Description..."
				}
			}
		}
		{
			name: unit
			display_name: "Timescale unit"
			type: {type: int}
			closure_bodies: {
				validate: "$env.state.timescale | is-not-empty"
				key_access: "$env.state.timescale"
			}
			atomic: {
				closure_bodies: {
					set: "$env.state.timescale = $timescales | util choose table --header 'Timescale unit:' | get id?"
				}
			}
		}
	]
	backmatter: "
if $p.task != null {
	$env.state = state read task $p.task | get state
	$env.id = $p.id
} else {
	let results = util exec form ./required-fields.gen.nu {
		prompt_prefix: (prompt prefix)
		name: null
		desc: null
		timescale: null
	}
	if $results == null {
		cancel
	}
	let state = {
		parent: null
        start: null
        end: null
        prereqs: []
        postreqs: []

		duration_cfg: {
            opt: 2
            exp: 4
            pes: 6
            total_cost: 0
        }
        children_cfgs: []
	} | merge $results
	let id = state save task $p.profile $state | get id
	$env.state = $state
	$env.id = $id
}
	"
}

const script_path = path self
$form | lib gen form $script_path
