# @usetype "./lib/gen/types.nu"
# @usetype "./lib/gen/form.nu"
# @usetype "../lib/proto/apipb/api.gen.nu"

use ./lib/gen/form.nu
use ./lib/gen/field.nu
use ./lib/gen/callback.nu
use ./lib/gen/types.nu
use ../lib/proto/apipb/api.gen.nu

# @type types.Field
let pert_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: pert
  display_name: PERT
  desc: "An estimation of the range of times "
  group: ""
  type: ((api.gen type PERT) | types optional)
  display_value: null
  init: (callback make [] "$params.pert?")
  ops: {
    read: true
    write: true
    validate: (
      {||
        let rng = $in
        if ($rng | is-empty) {
          return "PERT cannot be unset"
        }
        if $rng.opt > $rng.exp {
          return "PERT optimistic estimate (minimum duration) must be less than its expected estimate (average duration)"
        }
        if $rng.exp > $rng.pes {
          return "PERT expected estimate (average duration) must be less than its pessimistic estimate (maximum duration)"
        }
      } | callback from closure
    )
  }
}

# @type types.Field
let deadline_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: deadline
  display_name: Deadline
  desc: "The task deadline, after which, cost will apply."
  group: ""
  type: ({type: datetime} | types optional)
  display_value: null
  init: (callback make [] "$params.deadline?")
  ops: {
    read: true
    write: true
    validate: (
      {|| null } | callback from closure
    )
  }
}

# @type types.Field
let cost_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: total_cost
  display_name: Cost
  desc: "The cost of the task, the optimizer will try to minimize total amount of cost."
  group: ""
  type: {type: int}
  display_value: null
  init: (callback make [] "$params.cost? | default 0")
  ops: {
    read: true
    write: true
    validate: (
      {||
        if ($in == 0) {
          "cost cannot be null"
        }
      } | callback from closure
    )
  }
}

# @type list<types.Field>
let fields: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> = [
  $pert_field
  $deadline_field
  $cost_field
]

# @type list<form.InteractiveField>
let fields_ordering: list<record<field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>, interact: record<expr: string>>> = [
  {
    field: $cost_field
    interact: ($cost_field | field cmd interact set callback)
  }
  {
    field: $deadline_field
    interact: ($deadline_field | field cmd interact set callback)
  }
  {
    field: $pert_field
    interact: (callback make [] "print 'use the `set pert` command to set the PERT duration range'")
  }
]

# @type types.Command
let set_pert: record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> = {
  desc: "Set the PERT range of durations."
  group: ""
  aliases: []
  def: {
    name: "set pert"
    params: [
      [key value];
      [opt {type: duration}]
      [exp {type: duration}]
      [pes {type: duration}]
    ]
    body: $"{opt: $opt, exp: $exp, pes: $pes} | ($pert_field | field cmd write name)"
    in: {type: "nothing"}
    out: {type: "nothing"}
    env: true
    export: false
  }
}

# @type types.Form
let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> = {
  name: task-duration
  params: (api.gen type DurState | types fields optional | types optional)
  returns: (api.gen type DurState)
  use: []
  commands: [
    ...($fields | each { field cmds core } | flatten)

    ($deadline_field | field cmd interact set)
    ($cost_field | field cmd interact set)
    $set_pert

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
