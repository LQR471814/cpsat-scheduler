# nu-lint-ignore-file: dont_mix_different_effects
# @usetype "./lib/gen/types.nu"

use ./lib/gen/form.nu
use ./lib/gen/index.nu

const path_self = path self
let dir_self = $path_self | path dirname

# @type list<record<
#   path: string
#   name: string
#   obj: types.Form
# >>
let forms: list<record<path: string, name: string, obj: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>>>> = ls **/*.spec.nu
  | get name
  | par-each {
    let path: string = $in
    let name: string = $path | path basename | path parse | get stem
    # @type types.Form
    let form_obj: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> = nu $path
      | from nuon
    {
      path: $path
      name: $name
      obj: $form_obj
    }
  }

$forms
| par-each {|entry|
  try {
    $entry.obj
    | form render
    | save ($dir_self | path join $"gen/($entry.name).gen.nu") --force
  } catch {|err|
    print "GEN ERROR AT:" $entry.name
    print $err.rendered
  }
}

$forms
| get obj
| index generate ($dir_self | path join gen)

let errors = ls ($dir_self | path join ./gen/*.nu | into glob)
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
  | where not $it
if ($errors | is-empty) {
  print success.
}
