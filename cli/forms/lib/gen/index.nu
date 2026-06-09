# @usetype "./types.nu"

use ./form.nu

# @input list<types.Form>
# @output nothing
# @param out path
export def generate [out: path]: list<record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>>> -> nothing {
  let cmds = $in
    | par-each {|form|
      try {
        $form
        | form call
        | form render command def
      } catch {|err|
        print "INDEX ERROR AT:" $form.name
        print $err.rendered
      }
    }

  [
    "use ../lib/nav.nu"
    ...$cmds
  ]
  | str join "\n\n"
  | save ($out | path join ./index.nu) --force
}
