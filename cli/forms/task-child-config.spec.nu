# @usetype "./lib/gen/types.nu"
# @usetype "./lib/gen/form.nu"
# @usetype "../lib/proto/apipb/api.gen.nu"

use ./lib/gen/types.nu
use ./lib/gen/form.nu
use ./lib/gen/field.nu
use ./lib/gen/callback.nu
use ../lib/proto/apipb/api.gen.nu
use ./task-common.nu

let child_config_type = api.gen type ChildrenConfigState

# @type types.Field
let desc_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: desc
  display_name: Description
  desc: "Description of this possible set of children."
  group: ""
  type: ($child_config_type | types get field desc | types optional)
  display_value: null
  init: (callback make [] "$params.desc")
  ops: {
    read: true
    write: true
    validate: (
      callback make [] "if $in == null {
  'description cannot be null'
}"
    )
  }
}

# @type types.Field
let deadline_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: deadline
  display_name: Deadline
  desc: "If the parent is scheduled after the deadline, the expected cost will be added to the total cost."
  group: ""
  type: ($child_config_type | types get field deadline)
  display_value: null
  init: (callback make [] "$params.deadline")
  ops: {
    read: true
    write: true
    validate: (
      callback make [] "null"
    )
  }
}

# @type types.Field
let exp_cost_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: exp_cost
  display_name: "Expected Cost"
  desc: "The expected cost to be added to the global sum if the parent task is scheduled after the deadline."
  group: ""
  type: ($child_config_type | types get field exp_cost | types optional)
  display_value: null
  init: (callback make [] "$params.exp_cost")
  ops: {
    read: true
    write: true
    validate: (
      callback make [] "if ($in == null) {
  'expected cost cannot be null'
}"
    )
  }
}

# @type types.Field
let children_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: children
  display_name: Children
  desc: "The children that are part of this configuration. They must be scheduled within the bounds of the parent's scheduled timescale instance."
  group: ""
  type: ($child_config_type | types get field children)
  display_value: null
  init: (callback make [] "$params.children")
  ops: {
    read: true
    write: true
    validate: (
      callback make [] "if ($in | is-empty) {
  'cannot have a children config that contains no children. if you wish to specify a task with 0 duration, consider adding a child with explicit PERT range of (opt: 0, exp: 0, pes: 0).'
}"
    )
  }
}

# @type types.Command
let new_child_cmd = {
  desc: "Create a new task and add it to the list of children."
  group: ""
  aliases: [nc]
  def: {
    name: "new child"
    params: []
    in: {type: "nothing"}
    out: {type: "nothing"}
    env: true
    export: false
    body: $"
let result = {
  id: null
  profile_id: $params.profile_id
  state: null
} | index form task
if $result == null { return }

let id = {
  id: null
  profile_id: $params.profile_id
  state: $result
} | api.gen API SaveTask | get id\n($children_field | field cmd read name)
| append {
  id: $id
  name: $result.name
}
| ($children_field | field cmd write name)

null
    "
  }
}

# @type list<types.Field>
let fields: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> = [
  $desc_field
  $deadline_field
  $exp_cost_field
  $children_field
]

# @type list<form.InteractiveField>
let fields_ordering: list<record<field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>, interact: record<expr: string>>> = [
  {
    field: $desc_field
    interact: (callback make [] ($desc_field | field cmd interact set name))
  }
  {
    field: $exp_cost_field
    interact: (callback make [] ($exp_cost_field | field cmd interact set name))
  }
  {
    field: $deadline_field
    interact: (callback make [] ($deadline_field | field cmd interact set name))
  }
  {
    field: $children_field
    interact: (callback make [] ($children_field | field cmd interact list add name))
  }
]

# @type types.Form
let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> = {
  name: task-child-config
  params: (
    $child_config_type
    | update fields {
      append [
        {
          key: task_id
          value: {type: int}
        }
        {
          key: profile_id
          value: {type: int}
        }
      ]
    }
  )
  returns: $child_config_type
  use: []
  commands: [
    ...($fields | each { field cmds core } | flatten)

    ($desc_field | field cmd interact set)
    ($exp_cost_field | field cmd interact set)
    ($deadline_field | field cmd interact set)
    $new_child_cmd

    (
      $children_field | field cmd interact list add (
        callback make [] "{
  type: CHILD
  task_id: $params.task_id
}
| api.gen API ListPossibleRelatives
| get entries
| util choose table --header 'Choose a child to add:'"
      )
    )
    (
      $children_field | field cmd interact list remove (
        {|| $in } | callback from closure
      )
    )

    (form cmd cancel)
    ($fields | form cmd done)
    ($fields | form cmd status)
    ($fields_ordering | form cmd next)
  ]
  init: {
    before_cmds: ""
    after_cmds: $"($fields | form fields init)"
  }
}

$form | to nuon --raw
