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

let required_ids = task-common required ids
let task_type = api.gen type TaskState
let required_fields = task-common required fields
let optional_fields = task-common optional fields

def "access tmp task id" []: nothing -> string {
  "$env.__tmp_task_id"
}

# @input nothing
# @output string
def "write tmp task id run" []: nothing -> string {
  callback make [] "$env.__tmp_task_id = $in"
  | callback run
}

# @type types.Field
let req_fields_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: required
  display_name: "Required Fields"
  desc: "Required task fields."
  group: ""
  type: {type: record fields: $required_fields}
  display_value: null
  ops: {
    read: true
    write: true
    validate: (
      callback make [] $"
let v = $in
if \($v.name | is-empty\) {
  return 'name cannot be empty'
}
if $v.timescale == null {
  return 'timescale cannot be empty'
}

if (access tmp task id) != null {
  return
}

{
  id: null
  profile_id: $params.profile_id
  state: {
    name: $v.name
    desc: \($v.desc | default ''\)
    timescale: $v.timescale
    duration_cfg: {
      pert: {
        pert: {pes: 90min, exp: 1hr, opt: 30min}
        deadline: null
        total_cost: 0
      }
    }
    children_cfgs: []
    prereqs: []
    postreqs: []
    parent: null
    start: null
    end: null
  }
}
| api.gen API SaveTask
| get id
| (write tmp task id run)"
    )
  }
}

# @type types.Field
let opt_fields_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: optional
  display_name: "Optional Fields"
  desc: "Optional task fields."
  group: ""
  type: {type: record fields: $optional_fields}
  display_value: null
  ops: {
    read: true
    write: true
    validate: ({|| } | callback from closure)
  }
}

# delete task if cancel on newly created task (after required fields)
# @type callback.Callback
let remove_tmp_task = callback make [] $"if $is_creating and (access tmp task id) != null {
  {id: (access tmp task id)} | api.gen API DeleteTask
}"

# @type callback.Callback
let output = callback make [] $"($remove_tmp_task | callback run)\n($req_fields_field | field cmd read name)
| merge \(($opt_fields_field | field cmd read name)\)"

# @type list<types.Field>
let fields: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> = [
  $req_fields_field
  $opt_fields_field
]

# @type list<form.InteractiveField>
let fields_ordering: list<record<field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>, interact: record<expr: string>>> = [
  {
    field: $req_fields_field
    interact: ($req_fields_field | field cmd interact set callback)
  }
  {
    field: $opt_fields_field
    interact: ($opt_fields_field | field cmd interact set callback)
  }
]

# @type types.Form
let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> = {
  name: task
  params: {
    type: record
    fields: (
      $task_type.fields
      | append {
        key: id
        value: ({type: int} | types optional)
      }
    )
  }
  returns: $task_type
  use: []
  commands: [
    ...($fields | each { field cmds core } | flatten)

    (
      $req_fields_field | field cmd interact set --callback (
        callback make [] $"
let new_value = $in
  | ($req_fields_field | field cmd read name)
  | index form task-required
if $new_value == null { (form cmd cancel name) -y }
  "
      )
    )
    (
      $opt_fields_field | field cmd interact set --callback (
        callback make [] $"($opt_fields_field | field cmd read name) | index form task-optional"
      )
    )

    (form cmd cancel --before $remove_tmp_task)
    ($fields | form cmd done --output $output)
    ($fields | form cmd status)
    ($fields_ordering | form cmd next)
  ]
  init: $"
$params
| select ($required_ids | str join ' ')
| ($req_fields_field | field cmd write name)

$params
| reject ($required_ids | str join ' ')
| ($req_fields_field | field cmd write name)

$params.id | (write tmp task id run)

let is_creating = $params.id == null"
}

$form | to nuon --raw
