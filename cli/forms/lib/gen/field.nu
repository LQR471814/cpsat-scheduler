# nu-lint-ignore-file: check_typed_flag_before_use

# @usetype "./types.nu"
# @usetype "./callback.nu"

use callback.nu

# NOTE: Prefer (cmd read name) and (cmd write name) over this! This
# should only be used in the *very-rare* event you want to set or access
# a value but skip all typing!
#
#
# @input types.Field
# @output string
export def "state access" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> string {
  $"$env.__state_($in.id)"
}

# @input types.Field
# @output types.Command
export def "cmd read" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
  # @type types.Field
  let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in
  if not $field.ops.read {
    return null
  }
  {
    desc: $"Get the value of ($field.id)."
    group: $field.group
    aliases: []
    def: {
      name: $"read ($field.id)"
      params: []
      body: ($field | state access)
      in: {type: "nothing"}
      out: $field.type
      env: true
      export: false
    }
  }
}

# @input types.Field
# @output types.Command
export def "cmd write" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
  # @type types.Field
  let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in
  if not $field.ops.write {
    return null
  }
  {
    desc: $"Set the value of ($field.id)."
    group: $field.group
    aliases: []
    def: {
      name: $"write ($field.id)"
      params: [
        [key value];
        ["--skipval(-s)" {type: bool}]
      ]
      body: $"let new = $in
if $skipval {
  ($field | state access) = $new
  return
}
let err = $new | ($field.ops.validate | callback run)
if $err != null {
  util print error $err
  return
}\n($field | state access) = $new"
      in: $field.type
      out: {type: "nothing"}
      env: true
      export: false
    }
  }
}

# @input types.Field
# @output string
export def "cmd read name" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> string {
  $"read ($in.id)"
}

# `skipval` indicates that validation should be skipped after write
#
# @input types.Field
# @output string
# @param skipval bool
export def "cmd write name" [--skipval (-s)]: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> string {
  let args: string = if $skipval { "-s" } else { "" }
  $"write ($in.id) ($args)"
}

# `cmd write optional` is an expression which if the value passed in is
# null, write will be skipped
#
# `skipval` indicates that validation should be skipped after write
#
# @input types.Field
# @output string
# @param validate bool
export def "cmd write optional" [--skipval (-s)]: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> string {
  # @type types.Field
  let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in
  let call = $field | if $skipval {
      cmd write name -s
    } else {
      cmd write name
    }
  $"do {|| let v = $in; if $v == null { return }; ($call) }"
}

# @input types.Field
# @output types.Command
export def "cmd validate" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
  # @type types.Field
  let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in
  if $field.ops.validate == null {
    return null
  }
  {
    desc: $"Check if the current value of ($in.id) has any errors."
    group: $in.group
    aliases: []
    def: {
      name: ($field | cmd validate name)
      params: []
      body: $"($field | cmd read name) | ($in.ops.validate | callback run)"
      in: {type: "nothing"}
      out: {
        type: oneof
        positional: [
          {type: string}
          {type: "nothing"}
        ]
      }
      env: true
      export: false
    }
  }
}

# @input types.Field
# @output string
export def "cmd validate name" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> string {
  $"validate ($in.id)"
}

# @input types.Field
# @output list<types.Command>
export def "cmds core" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>> {
  [
    ($in | cmd read)
    ($in | cmd write)
    ($in | cmd validate)
  ]
  | where $it != null
}

# @input types.TypeDef
# @output callback.Callback
def "default interact setter" [desc: string --multiline]: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> -> record<expr: string> {
  # @type types.TypeDef
  let typedef: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> = $in
  let type: string = $typedef.type
  let body: string = match $type {
    string => {
      if $multiline {
        $"util input multiline ($desc | to json)"
      } else {
        $"util input text ($desc | to json)"
      }
    }
    int => {
      $"util input int ($desc | to json)"
    }
    float | number => {
      $"util input float ($desc | to json)"
    }
    bool => {
      $"util confirm --prompt ($desc | to json)"
    }
    datetime => {
      # TODO: add desc support to datepicker
      "util choose date"
    }
    oneof => {
      let notnull = $typedef.positional | where type != "nothing"
      if ($notnull | length) > 2 {
        error make {
          msg: $"oneof other than oneof<T, nothing> is currently unsupported"
          label: {
            text: "type def"
            span: (metadata $type).span
          }
        }
      }
      if $multiline {
        $notnull | first | default interact setter $desc --multiline
      } else {
        $notnull | first | default interact setter $desc
      }
      | callback run
    }
    _ => {
      error make {
        msg: $"unsupported type ($type)"
        label: {
          text: "type def"
          span: (metadata $type).span
        }
      }
    }
  }
  callback make [] $body
}

# - callback should prompt the user and return the new value to be set.
# - nullvalue indicates that callback returning null should not be
# interpreted as aborting the operation
#
# @input types.Field
# @output types.Command
# @param callback callback.Callback
export def "cmd interact set" [--callback: record<expr: string> --multiline --nullvalue (-n)]: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
  # @type types.Field
  let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in

  # @type callback.Callback
  let callback: record<expr: string> = $callback | default {
      if $multiline {
        $field.type | default interact setter $field.desc --multiline
      } else {
        $field.type | default interact setter $field.desc
      }
    }

  let call = $"($field | cmd read name) | ($callback | callback run)"

  let body = if not $nullvalue {
    $"let new = ($call)
if $new == null { return }
$new | ($field | cmd write name)"
  } else {
    $"($call) | ($field | cmd write name)"
  }

  {
    desc: $"Set ($field.id) interactively."
    group: $field.group
    aliases: []
    def: {
      name: ($field | cmd interact set name)
      params: []
      body: $body
      in: {type: "nothing"}
      out: {type: "nothing"}
      env: true
      export: false
    }
  }
}

# @input types.Field
# @output string
export def "cmd interact set name" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> string {
  $"set ($in.id)"
}

# @input types.Field
# @output callback.Callback
export def "cmd interact set callback" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<expr: string> {
  callback make [] ($in | cmd interact set name)
}

# @input types.Field
# @output types.Command
# @param callback callback.Callback
#
# NOTE: callback should be: nothing -> oneof<list_entry, nothing>
#
# if it returns null, it means to cancel
export def "cmd interact list add" [callback: record<expr: string>]: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
  # @type types.Field
  let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in

  if $field.type.type != list and $field.type.type != table {
    error make {
      msg: "input field type must be of either list or table"
      label: {
        text: "input field type name"
        span: (metadata $field.type.type).span
      }
    }
  }

  {
    desc: $"Add a value to list ($field.id) interactively."
    group: $field.group
    aliases: []
    def: {
      name: ($field | cmd interact list add name)
      params: []
      body: $"let orig = ($field | cmd read name)
let chosen = ($callback | callback run)
if $chosen == null { return }
$orig
	| append $chosen
	| ($field | cmd write name)"
      in: {type: "nothing"}
      out: {type: "nothing"}
      env: true
      export: false
    }
  }
}

# @input types.Field
# @output string
export def "cmd interact list add name" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> string {
  $"add ($in.id)"
}

# @input types.Field
# @output types.Command
# @param entry callback.Callback
#
# if it returns null, it means to cancel
export def "cmd interact list remove" [entry: record<expr: string>]: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
  # @type types.Field
  let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in

  if $field.type.type != list and $field.type.type != table {
    error make {
      msg: "input field type must be of either list or table"
      label: {
        text: "input field type"
        span: (metadata $field.type.type).span
      }
    }
  }

  {
    desc: $"Remove a value from list ($field.id) interactively."
    group: $field.group
    aliases: []
    def: {
      name: $"remove ($field.id)"
      params: []
      body: $"let orig = ($field | cmd read name)
let chosen = $orig
	| each {|row|
		\($row | ($entry | callback run)\)
	}
	| util choose table --header \('Remove: ' + ($field.desc | to json)\)
if $chosen == null { return }
if not \(util confirm --prompt $\"Are you sure you wish to remove \($chosen.name\)?\"\) { return }
$orig
	| where \($it | ($entry | callback run) | get id\) != $chosen.id
	| ($field | cmd write name)"
      in: {type: "nothing"}
      out: {type: "nothing"}
      env: true
      export: false
    }
  }
}

# @input types.Field
# @output types.Command
export def "cmd interact list list" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
  # @type types.Field
  let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in
  {
    desc: $"List the values of ($field.id)."
    group: $field.group
    aliases: []
    def: {
      name: $"list ($field.id)"
      params: []
      body: $"($field | cmd read name) | table -e | print"
      in: {type: "nothing"}
      out: {type: "nothing"}
      env: true
      export: false
    }
  }
}

# @input types.Field
# @output types.Command
# @param entry callback.Callback
# @param edit callback.Callback
#
# entry: list_entry -> record<id: primitive, name: string>
# edit: list_entry -> oneof<list_entry, nothing>
export def "cmd interact list edit" [entry: record<expr: string> edit: record<expr: string>]: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> {
  # @type types.Field
  let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in
  {
    desc: $"Choose a value of ($field.id) to edit."
    group: $field.group
    aliases: []
    def: {
      name: $"edit ($field.id)"
      params: []
      body: $"let orig = ($field | cmd read name)
	| each {|row|
		{
			row: $row
			entry: \($row | ($entry | callback run)\)
		}
	}

let chosen = $orig
	| get entry
	| util choose table --header \('Edit: ' + ($field.desc | to json)\)
if $chosen == null { return }

let new_row = $orig
	| where entry == $chosen
	| get row
	| ($edit | callback run)

if $new_row == null { return }

$orig
	| each {|row|
		if $in.entry == $chosen { $new_row } else { $row }
	}
	| ($field | cmd write name)"
      in: {type: "nothing"}
      out: {type: "nothing"}
      env: true
      export: false
    }
  }
}

# @input types.TypeDef
# @output callback.Callback
def "default display value callback" []: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> -> record<expr: string> {
  let typedef = $in
  let type = $typedef.type
  let body = match $type {
    string => { "print $in" }
    int | float | number => { "util print number $in" }
    bool => { "util print bool $in" }
    datetime => { "util print date $in" }
    duration => { "util print duration $in" }
    record | list | table => { "table -e | print" }
    "nothing" => { "print" }
    oneof => {
      let cases = $typedef.positional
        | each {
          let typedef = $in
          let expr = $typedef
            | default display value callback
            | get expr
          $"($typedef.type | to json) => { $in | do ($expr) }"
        }
        | str join "\n"

      $"match \($in | describe | parse -r `^\(?<type>\\w+\)` | get 0.type\) {\n($cases)\n}"
    }
    _ => {
      error make {
        msg: $"unsupported type ($type)"
        label: {
          text: "input type name"
          span: (metadata $type).span
        }
      }
    }
  }
  callback make [] $body
}

# display value callback gives the display value callback for a given field
#
# @input types.Field
# @output callback.Callback
export def "display value callback" []: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> -> record<expr: string> {
  # @type types.Field
  let field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $in
  $field.display_value | default { $field.type | default display value callback }
}
