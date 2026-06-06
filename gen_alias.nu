ls cli/**/*.nu
	| get name
	| str join "\n"
	| nu-type-alias

