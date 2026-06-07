use ../lib.nu # nu-lint-ignore: dont_mix_different_effects

let form = {
	name: children-config
	use: (lib form imports)
	frontmatter: null
	params: {
		type: record
		fields: [[key, value];
			[task  {type: int}]
			[children_cfgs {type: table}]
		]
	}
	returns: {type: table}
	closures: {
		returns_post_process: "get children_cfgs"
	}
	fields: [
		{
			name: config
			display_name: Configs
			type: {type: table}
			closure_bodies: {
				getter: "$env.state.children_cfgs"
				setter: "$env.state.children_cfgs = $in"
				display_value: "[
    (if ($in.desc | is-not-empty) {
        $in.desc | str substring 0..<12
    } else { null })
    $'cost: ($in.exp_cost)'
    $'children: ($in.children | length)'
] | str join ' '"
			}
			list: {
				closure_bodies: {
					add: "let results = {
	state: {
		task: $p.state.task
		desc: null
		deadline: null
		exp_cost: null
		children: []
	}
	prompt_prefix: (prompt prefix)
} | index form child-config
if $results == null { return }
$env.state.children_cfgs ++= [$results]"
					edit: "let result = {
	state: ($in | merge { taks: $p.state.task })
	prompt_prefix: (prompt prefix)
} | index form child-config
if $result == null { error make {msg: 'form aborted'} }
$result"
				}
			}
		}
	]
}

$form | to json --raw
