# @usetype "./lib/gen/types.nu"
# @usetype "./lib/gen/form.nu"
# @usetype "./lib/gen/callback.nu"
# @usetype "../lib/proto/apipb/api.gen.nu"

use ./lib/gen/form.nu
use ./lib/gen/field.nu
use ./lib/gen/callback.nu
use ./lib/gen/types.nu
use ../lib/proto/apipb/api.gen.nu
use ./task-common.nu

# @type types.Field
let parent_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: parent
  display_name: Parent
  desc: "Parent task"
  group: relationships
  type: (types entry record)
  display_value: null
  ops: {
    read: true
    write: true
    validate: ({|| } | callback from closure)
  }
}

# @type types.Field
let prereqs_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: prereqs
  display_name: Prerequisites
  desc: "Tasks that must be scheduled before this task."
  group: relationships
  type: (types entry table)
  display_value: null
  ops: {
    read: true
    write: true
    validate: (
      {||
        # TODO: add actual logic checking for impossible situations here
        # ex. no cycles (though maybe this is handled server-side, check later)
      } | callback from closure
    )
  }
}

# @type types.Field
let postreqs_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: postreqs
  display_name: Postrequisites
  desc: "Tasks that must be scheduled after this task."
  group: relationships
  type: (types entry table)
  display_value: null
  ops: {
    read: true
    write: true
    validate: (
      {||
        # TODO: add actual logic checking for impossible situations here
        # ex. no cycles (though maybe this is handled server-side, check later)
      } | callback from closure
    )
  }
}

# @type types.Field
let start_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: start
  display_name: Start
  desc: "An explicit time which the task must start after."
  group: explicit_range
  type: {type: datetime}
  display_value: null
  ops: {
    read: true
    write: true
    validate: ({|| } | callback from closure)
  }
}

# @type types.Field
let end_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: end
  display_name: End
  desc: "An explicit time which the task must start before."
  group: explicit_range
  type: {type: datetime}
  display_value: null
  ops: {
    read: true
    write: true
    validate: ({|| } | callback from closure)
  }
}

let validate_range = callback make [] $"
if ($start_field | field cmd read name) >= ($end_field | field cmd read name) {
  'explicit start cannot be >= end'
}"

# @type types.Field
let start_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $start_field
  | update ops.validate { $validate_range }

# @type types.Field
let end_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = $end_field
  | update ops.validate { $validate_range }

# @type list<types.Field>
let fields: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> = [
  $parent_field
  $prereqs_field
  $postreqs_field
  $start_field
  $end_field
]

# @type list<form.InteractiveField>
let fields_ordering: list<record<field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>, interact: record<expr: string>>> = $fields
  | each {
    {
      field: $in
      interact: ($in | field cmd interact set callback)
    }
  }

# @type types.Command
let parent_chooser_cmd: record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> = $parent_field
  | field cmd interact set --callback (
    callback make [] "
{
  type: PARENT
  task_id: $params.task_id
}
| api.gen API ListPossibleRelatives
| get entries
| util choose table --header 'Choose parent:'
"
  )

# this gives id and name of a prereq/postreq
#
# @type callback.Callback
let req_display_entry: record<expr: string> = {|| $in } | callback from closure

# @type types.Form
let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> = {
  name: task-optional
  params: {
    type: record
    fields: (
      task-common optional fields | append {
        key: task_id
        value: {type: int}
      }
    )
  }
  returns: {
    type: record
    fields: (task-common optional fields)
  }
  use: []
  commands: [
    ...($fields | each { field cmds core } | flatten)

    # parent choose field
    $parent_chooser_cmd

    # single value fields
    ...([$start_field $end_field] | each { field cmd interact set })

    # add prereq/postreq
    ...(
      [
        [reqtype field];
        [PREREQ $prereqs_field]
        [POSTREQ $postreqs_field]
      ] | each {|entry|
        let reqtype = $entry.reqtype
        let field = $entry.field
        $field | field cmd interact list add (
          callback make [] $"let chosen = {
  type: ($reqtype)
  task_id: $params.task_id
}
| api.gen API ListPossibleRelatives
| get entries
| util choose table --header 'Choose a ($reqtype) to add:'"
        )
      }
    )

    # remove prereq/postreq
    ...(
      [$prereqs_field $postreqs_field]
      | each {
        field cmd interact list remove $req_display_entry
      }
    )

    (form cmd cancel)
    ($fields | form cmd done)
    ($fields | form cmd status)
    ($fields_ordering | form cmd next)
  ]
  init: $""
}

$form | to nuon --raw
