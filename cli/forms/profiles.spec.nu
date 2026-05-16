use ./lib.nu

let form = {
	name: profiles
	params: {type: 'nothing'}
	returns: {type: 'nothing'}
	closures: {}
	fields: [
		{
			name: profiles
			display_name: Profiles
			type: {
				type: table
				fields: [[key value];
					[id {type: int}]
					[name {type: string}]
					[atomic_timescale (lib type proto duration)]
					[universe_start (lib type proto timestamp)]
					[gen_pert_choices ({type: int} | lib type optional)]
				]
			}
			closure_bodies: {
				getter: "$env.state"
				setter: "$env.state = $in"
			}
			list: {
				closure_bodies: {
					add_static: {
						name: "add profile"
						params: [[key value];
							[name {type: string}]
							[atomic_timescale {type: duration}]
							[universe_start {type: datetime}]
							[--pert_choices {type: int}]
						]
						in: {type: "nothing"}
						out: {type: "nothing"}
						body: "state create profile $name ($atomic_timescale | util to proto dur) ($universe_start | util to proto time) ($pert_choices | default 4) | complete
$env.state = state list profiles"
					}
					remove: {
						name: "remove profile"
						params: null
						in: {type: "nothing"}
						out: {type: "nothing"}
						body: "let element = get profiles
	| select id name
	| util choose table --header 'Choose a profile to remove:'
if $element == null {
	return false
}
state remove profile $element.id
$env.state = state list profiles"
					}
				}
			}
		}
	]
	backmatter: "$env.state = state list profiles"
}

const script_path = path self
$form | lib gen form $script_path

