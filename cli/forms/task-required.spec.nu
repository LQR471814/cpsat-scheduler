# @usetype "./lib/gen/types.nu"
# @usetype "./lib/gen/form.nu"
# @usetype "../lib/proto/apipb/api.gen.nu"

use ./lib/gen/types.nu
use ./lib/gen/form.nu
use ./lib/gen/field.nu
use ./lib/gen/callback.nu
use ../lib/proto/apipb/api.gen.nu
use ./task-common.nu

# @type types.Field
let name_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: name
  display_name: Name
  desc: "The name of the task."
  group: ""
  type: ({type: string} | types optional)
  display_value: null
  init: (callback make [] "$params.name")
  ops: {
    read: true
    write: true
    validate: (
      {||
        if ($in | is-empty) {
          "name cannot be empty"
        }
      } | callback from closure
    )
  }
}

# @type types.Field
let desc_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: desc
  display_name: Description
  desc: "The description of the task."
  group: ""
  type: ({type: string} | types optional)
  display_value: null
  init: (callback make [] "$params.desc")
  ops: {
    read: true
    write: true
    validate: (
      {||
        if ($in == null) {
          "description should not be null"
        }
      } | callback from closure
    )
  }
}

# @type types.Field
let timescale_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: timescale
  display_name: "Timescale Unit"
  desc: "Should be the upper-bound for task duration."
  group: ""
  type: ({type: int} | types optional)
  display_value: null
  init: (callback make [] "$params.timescale")
  ops: {
    read: true
    write: true
    validate: (
      callback make [] "
let unit: int = $in
if \($unit == null\) {
  \"timescale should not be null\"
}
let possible = $timescales | get id
if not \($unit in $possible\) {
  $\"the given timescale is not one of the possible timescales: ($possible)\"
}"
    )
  }
}

# @type list<types.Field>
let fields: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> = [
  $name_field
  $desc_field
  $timescale_field
]

# @type list<form.InteractiveField>
let fields_ordering: list<record<field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>, interact: record<expr: string>>> = $fields
  | each {
    {
      field: $in
      interact: ($in | field cmd interact set callback)
    }
  }

# @type types.Form
let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> = {
  name: task-required
  params: {
    type: record
    fields: [
      [key value];
      [name ({type: string} | types optional)]
      [desc ({type: string} | types optional)]
      [timescale ({type: int} | types optional)]
    ]
  }
  returns: {
    type: record
    fields: (task-common required fields)
  }
  use: []
  commands: [
    ...($fields | each { field cmds core } | flatten)
    ($name_field | field cmd interact set)
    ($desc_field | field cmd interact set --multiline)
    (
      $timescale_field | field cmd interact set --callback (
        callback make [] "$timescales
| util choose table --header 'Timescale unit (upper-bound for task duration):'
| get id?"
      )
    )

    (form cmd cancel)
    ($fields | form cmd done)
    ($fields | form cmd status)
    ($fields_ordering | form cmd next)
  ]
  init: {
    before_cmds: "
let timescales: table<id: int, name: string> = [
  [id name];
  [16 '4 hour']
  [96 'day']
  [672 'week']
  [2688 'month']
  [8064 'quarter']
  [32256 'year']
  [64512 '2 year']
  [129024 '4 year']
  [258048 '8 year']
  [516096 '16 year']
  [1032192 '32 year']
  [2064384 '64 year']
  [4128768 '128 year']
]
    "
    after_cmds: $"($fields | form fields init)"
  }
}

$form | to nuon --raw
