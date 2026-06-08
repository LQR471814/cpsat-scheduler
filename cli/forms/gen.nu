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
		let form_obj = nu $filepath | from nuon

		$form_obj
			| form render
			| save ($dir_self | path join $"($name).gen.nu") --force

		$form_obj
			| form call
			| form render command def
	}
	| str join "\n\n"
	| save ./gen/index.nu --force

