use ../lib.nu # nu-lint-ignore: dont_mix_different_effects

let cfg = {
	type: record
	fields: [[key value];
		[pert {
			type: record
			fields: [[key value];
				[opt {type: duration}]
				[exp {type: duration}]
				[pes {type: duration}]
			]
		}]
		[deadline ({type: datetime} | lib type optional)]
		[total_cost ({type: int} | lib type optional)]
	]
} | lib type optional

let form = {
	name: duration-config
	use: (lib form imports)
	frontmatter: null
	params: {
	type: record
	fields: [[key value];
		[task ({type: int} | lib type optional)]
		[cfg $cfg]
	]
}
	returns: $cfg
	closures: {
		param_post_process: "update cfg { default {
		pert: {
			opt: null
			exp: null
			pes: null
		}
		deadline: null
	} }"
		returns_post_process: "get cfg"
	}
	fields: [
		{
			name: pert
			display_name: "PERT (time estimates)"
			type: {
				type: record,
				fields: [[key value];
					[opt {type: duration}]
					[exp {type: duration}]
					[pes {type: duration}]
				]
			}
			closure_bodies: {
				getter: "$env.state.cfg.pert"
				setter: "$env.state.cfg.pert = $in"
				validate: "$env.state.cfg.pert.opt != null and $env.state.cfg.pert.exp != null and $env.state.cfg.pert.pes != null"
			}
			atomic: {
				closure_bodies: {
					set_static: {
						name: pert
						params: [[key value];
							[opt {type: duration}]
							[exp {type: duration}]
							[pes {type: duration}]
						]
						body: "{opt: $opt, exp: $exp, pes: $pes} | set pert"
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
				getter: "$env.state.cfg.deadline"
				setter: "$env.state.cfg.deadline = $in"
			}
			atomic: {
				closure_bodies: {
					set: "let results = util choose date
if $results != null { $results | set deadline }"
				}
			}
		}
		{
			name: cost
			display_name: "Expected cost under minimum time investment"
			type: {type: int}
			closure_bodies: {
				getter: "$env.state.cfg.total_cost"
				setter: "$env.state.cfg.total_cost = $in"
				validate: "$env.state.cfg.total_cost != null"
			}
			atomic: {
				closure_bodies: {
					set: "let results = util input int 'Expected cost...'
if $results != null { $results | set cost }"
				}
			}
		}
	]
}

$form | to json --raw
