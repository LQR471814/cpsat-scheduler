# @usetype "./lib/types.nu"

use ./lib/form.nu

const path_self = path self
let dir_self = $path_self | path dirname

ls **/*.spec.nu
	| get name
	| par-each {
		let filepath = $in
		let name = $filepath | path basename | path parse | get stem

		# @type types.Form
		let form_obj: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> = nu $filepath | from nuon

		$form_obj
			| form render
			| save ($dir_self | path join $"gen/($name).gen.nu") --force

		$form_obj
			| form call
			| form render command def
	}
	| str join "\n\n"
	| save ./gen/index.nu --force

