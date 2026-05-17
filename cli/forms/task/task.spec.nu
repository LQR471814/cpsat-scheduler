use ../lib.nu

let state = {
	type: record,
	fields: [[key value];
		[profile {type: int}]

		[payload {
			type: oneof
			positional: [
				{
					type: record
					fields: [[key value];
						[task {type: int}]
					]
				}
				{
					type: record
					fields: [[key value];
						[parent  ({type: int} | lib type optional)]
						[prereq  ({type: int} | lib type optional)]
						[postreq ({type: int} | lib type optional)]
						[child   ({type: int} | lib type optional)]
					]
				}
			]
		}]
	]
}

let parent_type = lib type entry record
let ts_type = lib type proto timestamp
let req_type = lib type entry table

let required_fields = [[key value];
	[name      {type: string}]
	[desc      {type: string}]
	[timescale {type: int}]
]
let optional_fields = [[key value];
	[parent   ($parent_type | lib type optional)]
	[start    ($ts_type | lib type optional)]
	[end      ($ts_type | lib type optional)]
	[prereqs  $req_type]
	[postreqs $req_type]
]

let dur_type = lib type proto duration
let deadline_type = lib type proto timestamp
let dur_cfg_fields = [[key value];
	[pert {
		type: record
		fields: [[key value];
			[opt $dur_type]
			[exp $dur_type]
			[pes $dur_type]
		]
	}]
	[deadline $deadline_type]
	[total_cost {type: int}]
]

let form = {
	name: task
	params: $state
	returns: $state
	closures: {
		returns_post_process: "let input = $in
state save task $p.state.profile $input
$input"
	}
	fields: [
		{
			name: req
			display_name: Required
			type: {
				type: record
				fields: $required_fields
			}
			closure_bodies: {
				getter: "$env.state | select name desc timescale"
				setter: "let value = $in
$env.state = $env.state | merge ($value | select name desc timescale)"
			}
			atomic: {
				closure_bodies: {
					set: "util exec form ./forms/task/required-fields.gen.nu {
						prompt_prefix: (prompt prefix)
						state: (get req)
					}"
				}
			}
		}
		{
			name: opt
			display_name: Optional
			type: {
				type: record
				fields: $optional_fields
			}
			closure_bodies: {
				getter: "$env.state | select parent start end prereqs postreqs"
				setter: "let value = $in
$env.state = $env.state | merge ($value | select parent start end prereqs postreqs)"
			}
			atomic: {
				closure_bodies: {
					set: "util exec form ./forms/task/optional-fields.gen.nu {
	prompt_prefix: (prompt prefix)
	state: (get opt | merge { id: $env.id })
}"
				}
			}
		}
		{
			name: dur
			display_name: "Duration configuration"
			type: ({
				type: record
				fields: $dur_cfg_fields
			} | lib type optional)
			closure_bodies: {
				getter: "$env.state | get dur_cfg"
				setter: "$env.state.dur_cfg = $in"
			}
			atomic: {
				closure_bodies: {
					set: "util exec form ./forms/task/duration-config.gen.nu {
	prompt_prefix: (prompt prefix)
	state: { task: $env.id, cfg: (get dur) }
}"
				}
			}
		}
		{
			name: children
			display_name: "Children configurations"
			type: {type: table}
			closure_bodies: {
				getter: "$env.state | get children_cfgs"
				setter: "$env.state.children_cfgs = $in"
			}
			atomic: {
				closure_bodies: {
					set: "util exec form ./forms/task/children-config-list.gen.nu {
	prompt_prefix: (prompt prefix)
	state: {
		task: $env.id
		children_cfgs: (get children)
	}
}"
				}
			}
		}
	]
	backmatter: "
if $p.state.payload.task? != null {
	$env.state = state read task $p.state.payload.task | get state
	$env.id = $p.state.payload.task
} else {
	let results = util exec form ./forms/task/required-fields.gen.nu {
		prompt_prefix: (prompt prefix)
		state: {
			name: null
			desc: null
			timescale: null
		}
	}
	if $results == null {
		cancel
	}
	let state = {
		parent: $p.state.payload.parent?
        start: $p.state.payload.start?
        end: $p.state.payload.end?
        prereqs: (if $p.state.payload.prereq? { [$p.state.payload.prereq] } else { [] })
        postreqs: (if $p.state.payload.postreq? { [$p.state.payload.postreq] } else { [] })

		duration_cfg: {
            opt: 2
            exp: 4
            pes: 6
            total_cost: 0
        }
        children_cfgs: []
	} | merge $results
	let id = state save task $p.state.profile $state | get id
	$env.state = $state
	$env.id = $id
}
	"
}

const script_path = path self
$form | lib gen form $script_path
