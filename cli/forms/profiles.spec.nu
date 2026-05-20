use ./lib.nu

let form = {
	name: profiles
	use: (lib form imports)
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
						body: "{
	name: $name
	atomic_timescale: $atomic_timescale
	universe_start: $universe_start
	gen_pert_choices: ($pert_choices | default 4)
} | api.gen API CreateProfile | complete
$env.state = {} | api.gen API ListProfiles"
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
{id: $element.id} | api.gen API RemoveProfile
$env.state = {} | api.gen API ListProfiles"
					}
				}
			}
		}
	]
	backmatter: "$env.state = {} | api.gen API ListProfiles"
}

$form | to json --raw

