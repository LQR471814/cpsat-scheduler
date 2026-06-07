# @usetype "./lib/types.nu"
# @usetype "../lib/proto/apipb/api.gen.nu"

use ./lib/form.nu
use ./lib/field.nu

# @type list<types.Field>
let fields: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> = [
	{
		id: profile
		display_name: Profiles
		desc: "List of existing profiles."
		group: field
		type: {type: record, fields: []}
	}
]

# @type types.Form
let form: record<name: string, params: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, closure: record<name: string, params: list<record<key: string, value: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, fields: list<record<key: string, value: any>>, positional: list<any>>, record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> = {
	name: profiles
	params: {type: 'nothing'}
	returns: {type: 'nothing'}
	use: []
	commands: [
		(form done cmd)
		(form cancel cmd)
	]
	init: null
# 	fields: [
# 		{
# 			name: profiles
# 			display_name: Profiles
# 			type: {
# 				type: table
# 				fields: [[key value];
# 					[id {type: int}]
# 					[name {type: string}]
# 					[atomic_timescale ({type: duration})]
# 					[universe_start ({type: datetime})]
# 					[gen_pert_choices ({type: int} | lib type optional)]
# 				]
# 			}
# 			closure_bodies: {
# 				getter: "$env.state"
# 				setter: "$env.state = $in"
# 			}
# 			list: {
# 				closure_bodies: {
# 					add_static: {
# 						name: "add profile"
# 						params: [[key value];
# 							[name {type: string}]
# 							[atomic_timescale {type: duration}]
# 							[universe_start {type: datetime}]
# 							[--pert_choices {type: int}]
# 						]
# 						in: {type: "nothing"}
# 						out: {type: "nothing"}
# 						body: "{
# 	name: $name
# 	atomic_timescale: $atomic_timescale
# 	universe_start: $universe_start
# 	gen_pert_choices: ($pert_choices | default 4)
# } | api.gen API CreateProfile
# $env.state = {} | api.gen API ListProfiles | get entries"
# 					}
# 					remove: {
# 						name: "remove profile"
# 						params: null
# 						in: {type: "nothing"}
# 						out: {type: "nothing"}
# 						body: "let element = get profiles
# 	| select id name
# 	| util choose table --header 'Choose a profile to remove:'
# if $element == null {
# 	return false
# }
# {id: $element.id} | api.gen API RemoveProfile
# $env.state = {} | api.gen API ListProfiles | get entries"
# 					}
# 				}
# 			}
# 		}
# 	]
	# backmatter: "$env.state = {} | api.gen API ListProfiles | get entries"
}

$form | to nuon --raw

