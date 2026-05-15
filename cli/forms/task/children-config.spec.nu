use ../lib.nu # nu-lint-ignore: dont_mix_different_effects

let state_type = {
	type: record
	fields: [[key, value];
		[task  {type: int}]
		[children_cfgs {type: table}]
	]
}

let form = {
	name: children-configs
	frontmatter: null
	params: $state_type
	returns: $state_type
	closures: {}
	fields: [
		{
			name: configs
			display_name: Configs
			type: {type: table}
			closure_bodies: {
				key_access: "$env.state.children_cfgs"
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
					add: "let results = util exec form ./children-config.gen.nu {
	task: $p.task
	state: null
	prompt_prefix: (prompt prefix)
}
if $results == null { return }
$env.state.children_cfgs ++= $results"
				}
			}
		}
	]
	backmatter: status
}

const self_path = path self
$form | lib gen form $self_path
