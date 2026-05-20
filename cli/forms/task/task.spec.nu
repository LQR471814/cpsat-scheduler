use ../lib.nu

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
	[deadline ($deadline_type | lib type optional)]
	[total_cost {type: int}]
]

let payload = {
	type: oneof
	positional: [
		{type: "nothing"}
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
}

let form = {
	name: task
	use: (lib form imports)
	params: {
		type: record,
		fields: [[key value];
			[profile {type: int}]
			[payload $payload]
		]
	}
	returns: {
		type: record,
		fields: [[key value];
			[id {type: int}]]
	}
	closures: {
		returns_post_process: "let input = $in | get payload
{profile_id: $p.state.profile, state: $input} | api.gen API SaveTask"
	}
	fields: [
		{
			name: req
			display_name: "Required fields"
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
					set: "let results = {
	prompt_prefix: (prompt prefix)
	state: (get req)
} | index form required-fields
if $results != null { $results | set req }"
				}
			}
		}
		{
			name: opt
			display_name: "Optional fields"
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
					set: "let results = {
	prompt_prefix: (prompt prefix)
	state: (get opt | merge { id: $env.id })
} | index form optional-fields
if $results != null { $results | set opt }"
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
				getter: "$env.state | get duration_cfg"
				setter: "$env.state.duration_cfg = $in"
			}
			atomic: {
				closure_bodies: {
					set: "let results = {
	prompt_prefix: (prompt prefix)
	state: { task: $env.id, cfg: (get dur) }
} | index form duration-config
if $results != null { $results | set dur }"
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
					set: "let results = {
	prompt_prefix: (prompt prefix)
	state: {
		task: $env.id
		children_cfgs: (get children)
	}
} | index form children-config
if $results != null { $results | set children_cfgs }"
				}
			}
		}
	]
	backmatter: "
if $p.state.payload.task? != null {
	$env.state = {id: $p.state.payload.task} | api.gen API ReadTask | get state
	$env.id = $p.state.payload.task
} else {
	let results: record<name: string, desc: oneof<string, nothing>, timescale: int> = {
		prompt_prefix: (prompt prefix)
		state: {
			name: null
			desc: null
			timescale: null
		}
	} | index form required-fields
	if $results == null {
		cancel
	}
	let state = {
		name: $results.name
		desc: $results.desc
		timescale: $results.timescale

		parent: $p.state.payload.parent?
        start: $p.state.payload.start?
        end: $p.state.payload.end?
        prereqs: (if $p.state.payload.prereq? != null { [$p.state.payload.prereq] } else { [] })
        postreqs: (if $p.state.payload.postreq? != null { [$p.state.payload.postreq] } else { [] })

		duration_cfg: {
			pert: {
				opt: (30min | util to proto dur)
				exp: (1hr | util to proto dur)
				pes: (1hr + 30min | util to proto dur)
			}
			deadline: null
            total_cost: 0
        }
        children_cfgs: []
	}
	let id = {profile_id: $p.state.profile, state: $state} | api.gen API SaveTask | get id
	$env.state = $state
	$env.id = $id
}
	"
}

$form | to json --raw
