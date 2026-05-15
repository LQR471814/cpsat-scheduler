use ../lib.nu # nu-lint-ignore: dont_mix_different_effects

let dur_type = lib type proto duration
let deadline_type = lib type proto timestamp

let state_type = {
	type: record
	fields: [[key value];
		[task ({type: int} | lib type optional)]
		[cfg ({
			type: record
			fields: [[key value];
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
		} | lib type optional)]
	]
}

let form = {
	name: duration-config
	frontmatter: null
	params: $state_type
	returns: $state_type
	closures: {
		param_post_process: "update cfg { default {
		pert: {
			opt: null
			exp: null
			pes: null
		}
		deadline: null
	} }
| update cfg.pert.opt? { util from proto duration }
| update cfg.pert.exp? { util from proto duration }
| update cfg.pert.pes? { util from proto duration }
| update cfg.deadline? { util from proto time }"
		returns_post_process: "update cfg.pert.opt? { util to proto duration }
| update cfg.pert.exp? { util to proto duration }
| update cfg.pert.pes? { util to proto duration }
| update cfg.deadline? { util to proto time }"
	}
	fields: [
		{
			name: pert
			display_name: "PERT (time estimates)"
			type: {
				type: list,
				positional: [
					{type: int}
				]
			}
			closure_bodies: {
				key_access: "$env.state.cfg.pert"
				validate: "$env.state.cfg.pert.opt != null and $env.state.cfg.pert.exp != null and $env.state.cfg.pert.pes != null"
			}
			atomic: {
				closure_bodies: {
					set_static: {
						name: "set pert"
						params: [[key value];
							[opt {type: int}]
							[exp {type: int}]
							[pes {type: int}]
						]
						body: "$env.state.cfg.pert = {opt: $opt, exp: $exp, pes: $pes}"
						in: {type: "nothing"}
						out: {type: "nothing"}
					}
				}
			}
		}
		{
			name: deadline
			display_name: Deadline
			type: ({type: datetime} | lib type optional)
			closure_bodies: {
				key_access: "$env.state.cfg.deadline"
			}
			atomic: {
				closure_bodies: {
					set: "util choose date"
				}
			}
		}
		{
			name: cost
			display_name: "Expected cost under minimum time investment"
			type: {type: int}
			closure_bodies: {
				key_access: "$env.state.cfg.total_cost"
				validate: "$env.state.cfg.total_cost != null"
			}
			atomic: {
				closure_bodies: {
					set: "util input int"
				}
			}
		}
	]
	backmatter: status
}

const self_path = path self
$form | lib gen form $self_path
