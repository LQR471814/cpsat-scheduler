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
				getter: "$env.state | default []"
				setter: "$env.state = $in"
			}
			list: {
				closure_bodies: {}
			}
		}
	]
	backmatter: "$env.state = state list profiles"
}

const script_path = path self
$form | lib gen form $script_path

