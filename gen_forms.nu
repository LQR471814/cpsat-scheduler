go run ./cmd/gen/form ./cli | complete # nu-lint-ignore: dont_mix_different_effects

let checks = ls cli/**/*.nu
	| each {
		let entry = $in
		try {
			nu-check --debug $entry.name
		} catch {|err|
			print $entry.name ($err | get msg)
			print ""
			false
		}
	}

ls ./cli/forms/gen/**/*.nu
	| get name
	| each { $"($in)\n" }
	| str join ""
	| nu-type-alias

let errors = $checks | where not $it
if ($errors | is-empty) {
	print success.
}
