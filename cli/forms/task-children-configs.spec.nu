# @usetype "./lib/gen/types.nu"
# @usetype "./lib/gen/form.nu"
# @usetype "../lib/proto/apipb/api.gen.nu"

use ./lib/gen/types.nu
use ./lib/gen/form.nu
use ./lib/gen/field.nu
use ./lib/gen/callback.nu
use ../lib/proto/apipb/api.gen.nu
use ./task-common.nu

# @type types.TypeDef
let children_configs_type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> = {
  type: list
  positional: [(api.gen type ChildrenConfigState)]
}

# @type types.Field
let children_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: configs
  display_name: "Children Configs"
  desc: "List of children configurations."
  group: ""
  type: $children_configs_type
  display_value: null
  init: (callback make [] "$params.children")
  ops: {
    read: true
    write: true
    validate: (
      callback make [] "null"
    )
  }
}

# @type list<types.Field>
let fields: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> = [
  $children_field
]

# @type list<form.InteractiveField>
let fields_ordering: list<record<field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>, interact: record<expr: string>>> = [
  {
    field: $children_field
    interact: (callback make [] ($children_field | field cmd interact list add name))
  }
]

# @type types.Form
let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> = {
  name: task-children-configs
  params: {
    type: record
    fields: [
      [key value];
      [task_id {type: int}]
      [children $children_configs_type]
    ]
  }
  returns: $children_configs_type
  use: []
  commands: [
    ...($fields | each { field cmds core } | flatten)

    (
      $children_field | field cmd interact list add (
        callback make [] "{
  task_id: $params.task_id
  desc: null
  deadline: null
  exp_cost: null
  children: []
} | index form task-child-config"
      )
    )
    (
      $children_field | field cmd interact list edit (
        {|idx| {id: $idx name: $in.desc} } | callback from closure
      ) (
        callback make [] "$in
| merge {task_id: $params.task_id}
| index form task-child-config"
      )
    )
    (
      $children_field | field cmd interact list remove (
        {|idx|
          {id: $idx name: $in.desc}
        } | callback from closure
      )
    )

    (form cmd cancel)
    ($fields | form cmd done --output (callback make [] ($children_field | field cmd read name)))
    ($fields | form cmd status)
    ($fields_ordering | form cmd next)
  ]
  init: {
    before_cmds: ""
    after_cmds: $"($fields | form fields init)"
  }
}

$form | to nuon --raw
