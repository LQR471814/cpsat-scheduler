ls cli/**/*.spec.nu
	| par-each { nu $in.name }
print "success."
