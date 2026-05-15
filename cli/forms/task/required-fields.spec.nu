use ../lib.nu

const script_path = path self | path dirname # nu-lint-ignore: dont_mix_different_effects

let state = [[key, value];
	[id {type: oneof, generic_unnamed: [{type: int} {type: "nothing"}]}]
	[name {type: oneof, generic_unnamed: [{type: string} {type: "nothing"}]}]
	[desc {type: oneof, generic_unnamed: [{type: string} {type: "nothing"}]}]
	[timescale {type: oneof, generic_unnamed: [{type: int} {type: "nothing"}]}]
]

let frontmatter = 'let timescales: table<id: int, name: string> = [[id, name];
    [96, "day"]
    [672, "week"]
    [2688, "month"]
    [8064, "quarter"]
    [32256, "year"]
    [64512, "2 year"]
    [129024, "4 year"]
    [258048, "8 year"]
    [516096, "16 year"]
    [1032192, "32 year"]
    [2064384, "64 year"]
    [4128768, "128 year"]
]'

let form = {
	name: required-fields
	frontmatter: $frontmatter
	params: {
		type: record
		fields: $state
	}
	returns: {
		type: record
		fields: $state
	}
	closures: {}
	fields: [
		{
			name: name
			display_name: Name
			type: {type: string}
			closure_bodies: {
				validate: "$env.state.name | is-not-empty"
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
			name: timescale
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
}

const script_path = path self
$form | lib gen form $script_path
