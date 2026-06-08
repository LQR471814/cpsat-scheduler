print "formatting..."
ls **/*.nu
| par-each { topiary-nushell format $in.name }
null
