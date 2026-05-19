go run ./cmd/gen/form ./cli | complete

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

let errors = $checks | where not $it
if ($errors | is-empty) {
	print "success."
}
