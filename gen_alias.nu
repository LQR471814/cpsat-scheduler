ls cli/**/*.nu
| get name
| where not ($it | str ends-with .gen.nu)
| str join "\n"
| nu-type-alias
