# @usetype "./types.nu"
# @usetype "./callback.nu"

use field.nu
use callback.nu
use types.nu

# creates a command that validates all fields before returning the form
#
# @input list<types.Field>
# @output types.Command
# @param output callback.Callback
#
# output: nothing -> any
export def "cmd done" [--output: record<expr: string>]: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
  # @type list<types.Field>
  let fields: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> = $in

  let validation = $fields
    | each {|field|
      if $field.ops.validate == null { return }
      # @type types.Field
      let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $field
      $"let err = ($field | field cmd read name) | ($field.ops.validate | callback run)
if $err != null {
	error make $err
}"
    }
    | where $it != null
    | str join "\n"

  let output: string = if $output == null {
    $fields
    | each {|field|
      # @type types.Field
      let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $field
      $"\t'($field.id)': \(($field | field cmd read name)\)"
    }
    | str join "\n"
  } else {
    $output | callback run
  }

  let body = $"($validation)
{($output)
} | nav save form output
exit"
  {
    desc: "Validate and submit form."
    group: control
    aliases: [d]
    def: {
      name: done
      params: []
      body: $body
      in: {type: "nothing"}
      out: {type: "nothing"}
      env: false
      export: false
    }
  }
}

# @input nothing
# @output types.Command
export def "cmd cancel" []: nothing -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
  let body = "if not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }
null | nav save form output
exit # nu-lint-ignore: exit_only_in_main"

  {
    desc: "Abort submission and discard changes."
    group: control
    aliases: [c]
    def: {
      name: cancel
      params: []
      body: $body
      in: {type: "nothing"}
      out: {type: "nothing"}
      env: false
      export: false
    }
  }
}

# @input list<types.Field>
# @output types.Command
export def "cmd status" []: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
  # @type list<types.Field>
  let fields: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> = $in
  let body = $fields
    | each {|field|
      # @type types.Field
      let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $field
      let valid = if $field.ops.validate != null {
        $"let err = ($field | field cmd read name) | ($field.ops.validate | callback run)
if $err != null {
	util print error $err
}"
      }
      [
        $"util print label '($field.display_name) [($field.group)]'"
        $"util print desc '($field.desc)'"
        $"($field | field cmd read name) | ($field | field display value callback | callback run) | print"
        $valid
        "print ''"
      ]
      | where $it != null
      | str join "\n"
    }
    | str join "\n"
  {
    desc: "Show the current form status."
    group: control
    aliases: [s]
    def: {
      name: status
      params: []
      in: {type: "nothing"}
      out: {type: "nothing"}
      body: $body
      env: false
      export: false
    }
  }
}

# export type InteractiveField = record<
#   field: types.Field
#   interact: callback.Callback
# >
#
# @input list<InteractiveField>
# @output types.Command
export def "cmd next" []: list<record<field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>, interact: record<expr: string>>> -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
  # @type list<InteractiveField>
  let fields: list<record<field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>, interact: record<expr: string>>> = $in

  # pick next form field w/ err
  # print error and abort if validate throws after filling

  let steps = $fields
    | each {|row|
      # @type types.Field
      let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $row.field
      # @type callback.Callback
      let interact: record<expr: string> = $row.interact

      $"if \(($field | field cmd validate name)\) != null {
	($interact | callback run)
	let err = ($field | field cmd validate name)
	if $err != null {
		util print error $err
		return false
	}
	return \(next\)
}"
    }
    | str join "\n"
  let body = $"($steps)
return true"
  {
    desc: "Fill in the next unfilled fields interactively."
    group: control
    aliases: [n]
    def: {
      name: next
      params: []
      in: {type: "nothing"}
      out: {type: "bool"}
      body: $body
      env: false
      export: false
    }
  }
}

# @input types.Form
# @output callback.Callback
def "default prompt prefix" []: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> -> record<expr: string> {
  callback make [] $"$\"\($prompt_prefix\) \\\(($in.name)\\\) \($in | do $default_prompt_prefix\)\""
}

# @input types.Form
# @output types.TypeDef
def "input type" []: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> -> oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> {
  {
    type: record
    fields: [
      {
        key: prompt_prefix
        value: {type: string}
      }
      {
        key: params
        value: $in.params
      }
    ]
  }
}

# @input types.Form
# @output string
def aliases []: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> -> string {
  get commands
  | each {|cmd|
    # @type types.Command
    let cmd: record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> = $cmd
    $cmd.aliases | each {|alias|
      $"alias ($alias) = ($cmd.def.name)"
    }
  }
  | flatten
  | str join "\n"
}

# @input types.Form
# @output types.CommandDef
def "cmd cmds" []: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> -> record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool> {
  # @type types.Form
  let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> = $in

  let rows = $form.commands
    | each {|cmd|
      # @type types.Command
      let cmd: record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> = $cmd
      [$cmd.group $cmd.def.name $cmd.aliases $cmd.desc] | to json -r
    }
    | str join "\n"

  let table_def = $"[[group name aliases desc];($rows)]"

  {
    name: cmds
    params: []
    body: $table_def
    in: {type: "nothing"}
    out: {
      type: table
      fields: [
        [key value];
        [group {type: string}]
        [name {type: string}]
        [
          aliases
          {
            type: list
            positional: [
              {type: string}
            ]
          }
        ]
        [desc {type: string}]
      ]
    }
    env: false
    export: false
  }
}

# @input types.Form
# @output string
def setup []: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> -> string {
  # @type types.Form
  let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> = $in

  $"let __input: ($form | input type | types render) = nav get form params

let prompt_prefix: string = $__input.prompt_prefix
let params: ($form.params | types render) = $__input.params

let default_prompt_prefix: closure = $env.PROMPT_COMMAND
$env.PROMPT_COMMAND = ($form | default prompt prefix | $in.expr)($form.init | default '')

cmds | table -e | print"
}

# @input types.CommandDef
# @output string
export def "render command def" []: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool> -> string {
  # @type types.CommandDef
  let cmd: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool> = $in

  let export: string = if $cmd.export { "export " } else { "" }
  let envflag: string = if $cmd.env { "--env " } else { "" }
  let params: string = $cmd.params
    | each {
      $"($in.key): ($in.value | types render)"
    }
    | str join " "
  let in_type: string = $cmd.in
    | types render
  let out_type: string = $cmd.out
    | types render
  let body = $cmd.body

  $"($export)def ($envflag)'($cmd.name)' [($params)]: ($in_type) -> ($out_type) {\n($body)\n}"
}

# @input types.Form
# @output string
export def render []: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> -> string {
  # @type types.Form
  let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> = $in

  let uses = $form.use
    | each { $"use '($in)'" }
    | str join "\n"
  let setup = $form | setup
  let cmds: string = $form.commands
    | each { $in.def | render command def }
    | append ($form | cmd cmds | render command def)
    | str join "\n\n"
  let aliases = $form | aliases

  [
    $"use index.nu
use ../lib/nav.nu
use ../../lib/util.nu
use ../../lib/proto/apipb/api.gen.nu"
    $uses
    $cmds
    $setup
    $aliases
  ] | str join "\n\n"
}

# @input types.Form
# @output types.CommandDef
export def call []: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> -> record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool> {
  # @type types.Form
  let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> = $in
  {
    name: $"form ($form.name)"
    params: []
    body: $"nav exec form './gen/($form.name).spec.gen.nu' $in"
    in: ($form | input type)
    out: ($form.returns)
    env: false
    export: true
  }
}
