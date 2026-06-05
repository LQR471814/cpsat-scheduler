ls cli/**/*.nu
	| get name
	| each { $"($in)\n" }
	| str join ""
	| nu-type-alias

