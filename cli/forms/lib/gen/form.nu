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
export def "cmd done" [--output: record<expr: string>]: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>        {
  # @type list<types.Field>
  let fields: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> = $in

  let validation = $fields
    | each {|field|
      if $field.ops.validate == null { return }
      # @type types.Field
      let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $field
      $"let err = ($field | field cmd read name) | ($field.ops.validate | callback run)
if $err != null {
  util print label '($field.display_name):'
	util print error $err
  return
}"
    }
    | where $it != null
    | str join "\n"

  let output: string = if $output == null {
    let object_body = $fields
    | each {|field|
      # @type types.Field
      let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $field
      $"'($field.id)': \(($field | field cmd read name)\)"
    }
    | str join "\n"
    $"{($object_body)}"
  } else {
    $output | callback run
  }

  let body = $"($validation)\n($output) | nav save form output

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
      env: true
      export: false
    }
  }
}

# @input nothing
# @output types.Command
# @param before callback.Callback
#
# before should return nothing, it is called right before exiting
export def "cmd cancel" [--before: record<expr: string>]: nothing -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>        {
  let body = $"if not $no_prompt and not \(util confirm --prompt 'Are you sure you want to abort? \(changes will not be saved\)'\) { return }
(if $before != null { $before | callback run } else { "" })
null | nav save form output
exit # nu-lint-ignore: exit_only_in_main"

  {
    desc: "Abort submission and discard changes."
    group: control
    aliases: [c]
    def: {
      name: (cmd cancel name)
      params: [
        [key value];
        ["--no-prompt(-y)" {type: bool}]
      ]
      body: $body
      in: {type: "nothing"}
      out: {type: "nothing"}
      env: true
      export: false
    }
  }
}

# @input nothing
# @output string
export def "cmd cancel name" []: nothing -> string {
  "cancel"
}

# @input list<types.Field>
# @output types.Command
export def "cmd status" []: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>        {
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
        (if ($field.group | is-not-empty) {
          $"util print label '($field.display_name) [($field.group)]'"
        } else {
          $"util print label '($field.display_name)'"
        })
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
      env: true
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
export def "cmd next" []: list<record<field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>, interact: record<expr: string>>> -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>        {
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
      env: true
      export: false
    }
  }
}

# @input types.Form
# @output types.CommandDef
def "cmd prompt prefix" []: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> -> record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool> {
  {
    name: (cmd prompt prefix name)
    params: []
    body: $"$\"\($prompt_prefix\) \\\(($in.name)\\\)\""
    in: {type: "nothing"}
    out: {type: string}
    env: false
    export: false
  }
}

# @input nothing
# @output string
export def "cmd prompt prefix name" []: nothing -> string {
  "prompt prefix"
}

# @input types.Form
# @output types.TypeDef
def "input type" []: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> -> oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> {
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
def aliases []: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> -> string {
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
def "cmd cmds" []: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> -> record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool> {
  # @type types.Form
  let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> = $in

  let rows = $form.commands
    | each {|cmd|
      # @type types.Command
      let cmd: record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> = $cmd
      [$cmd.group $cmd.def.name ($cmd.aliases | str join ', ') $cmd.desc] | to json -r
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
        [aliases {type: string}]
        [desc {type: string}]
      ]
    }
    env: true
    export: false
  }
}

# @input types.Form
# @output string
def "init before cmds" []: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> -> string {
  # @type types.Form
  let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> = $in

  let prompt_callback = callback make [] $"$\"\((cmd prompt prefix name)\) \($in | do $default_prompt_prefix\)\""

  $"let __input: ($form | input type | types render) = nav get form params

let prompt_prefix: string = $__input.prompt_prefix
let params: ($form.params | types render) = $__input.params

let default_prompt_prefix: closure = $env.PROMPT_COMMAND
$env.prompt_prefix = {|| (cmd prompt prefix name) }
$env.PROMPT_COMMAND = ($prompt_callback | callback run)\n($form.init.before_cmds)"
}

# @input types.Form
# @output string
def "init after cmds" []: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> -> string {
  $"cmds | table -e | print\n($in.init.after_cmds)"
}

# @input types.CommandDef
# @output string
export def "render command def" []: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool> -> string {
  # @type types.CommandDef
  let cmd: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool> = $in

  let export: string = if $cmd.export { "export " } else { "" }
  let envflag: string = if $cmd.env { "--env " } else { "" }
  let params: string = $cmd.params
    | each {|param|
      if $param.value.type == bool and ($param.key | str starts-with "-") {
        return $param.key
      }
      $"($param.key): ($param.value | types render)"
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
export def render []: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> -> string {
  # @type types.Form
  let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> = $in

  let uses = $form.use
    | each { $"use '($in)'" }
    | str join "\n"
  let cmds: string = $form.commands
    | each { $in.def | render command def }
    | append ($form | cmd cmds | render command def)
    | str join "\n\n"
  let aliases = $form | aliases

  let ctrl_d_hook = if ($form.commands | where def.name == cancel | is-not-empty) {
    "$env.config.keybindings = $env.config.keybindings | append {
  name: ctrl_d_hook
  modifier: control
  keycode: char_d
  mode: [emacs vi_insert vi_normal]
  event: {
    send: executehostcommand
    cmd: 'cancel'
  }
}"
  } else { "" }

  [
    $"# @usetype "../../lib/proto/apipb/api.gen.nu"

use index.nu
use ../lib/nav.nu
use ../../lib/util.nu
use ../../lib/proto/apipb/api.gen.nu"
    $uses
    ($form | init before cmds)
    ($form | cmd prompt prefix | render command def)
    $cmds
    $ctrl_d_hook
    ($form | init after cmds)
    $aliases
  ] | str join "\n\n"
}

# @input types.Form
# @output types.CommandDef
export def call []: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> -> record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool> {
  # @type types.Form
  let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> = $in
  {
    name: $"form ($form.name)"
    params: []
    body: $"nav exec form './gen/($form.name).spec.gen.nu' $in"
    in: $form.params
    out: $form.returns
    env: true
    export: true
  }
}
