# @usetype "./lib/gen/types.nu"
# @usetype "./lib/gen/form.nu"
# @usetype "../lib/proto/apipb/api.gen.nu"

use ./lib/gen/form.nu
use ./lib/gen/field.nu
use ./lib/gen/callback.nu
use ../lib/proto/apipb/api.gen.nu

# @type types.TypeDef
let existing_task: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> = {
  type: record
  fields: [
    [key value];
    [id {type: int}]
    [state (api.gen type TaskState)]
  ]
}

# @type types.TypeDef
let modified_list_type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> = {
  type: list
  positional: [$existing_task]
}

# @type types.Field
let modified_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: modified
  display_name: "Modified Tasks"
  desc: "The tasks that have been modified during this progress update."
  group: ""
  type: $modified_list_type
  display_value: null
  init: (callback make [] "[]")
  ops: {
    read: true
    write: true
    validate: (
      {||
        if ($in | is-empty) {
          'must modify at least one task in a progress update'
        }
      } | callback from closure
    )
  }
}

# @type list<types.Field>
let fields: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> = [
  $modified_field
]

# @type list<form.InteractiveField>
let fields_ordering: list<record<field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, init: record<expr: string>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>, interact: record<expr: string>>> = [
  {
    field: $modified_field
    interact: (callback make [] ($modified_field | field cmd interact list add name))
  }
]

let profile_id_access = "$params.profile_id"
let fetch_scheduled_pipe = "api.gen API ListScheduledTasks | get entries"
let choose_task_pipe = "util choose table --header 'Choose a task:' | get id?"

# @type types.Command
let update_task = {
  desc: "Update a task."
  group: ""
  aliases: []
  def: {
    name: "update task"
    params: []
    in: {type: int}
    out: {type: "nothing"}
    body: $"let updated = {
  id: $in
  state: \({id: $in} | api.gen API ReadTask | get state\)
  profile_id: ($profile_id_access)
} | index form task

if $updated == null { return }\n($modified_field | field cmd read name)
| append $updated
| ($modified_field | field cmd write name)"
    export: false
    env: true
  }
}

# @type types.Command
let pick_scheduled: record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> = {
  desc: "Pick a task scheduled in the time since the last progress update."
  group: ""
  aliases: [ps]
  def: {
    name: "pick scheduled"
    params: []
    in: {type: "nothing"}
    out: {type: "nothing"}
    body: $"let last_ckpt = {profile: ($profile_id_access)} | api.gen API GetLastCheckpoint
  | get time
if $last_ckpt == null {
  error make {msg: 'last checkpoint does not exist'}
}
let timescale = util choose timescale
let chosen = {
  profile_id: ($profile_id_access)
  timescale: $timescale
  start: $last_ckpt
  end: \(date now\)
} | ($fetch_scheduled_pipe) | ($choose_task_pipe)
if $chosen == null { return }
$chosen | ($update_task.def.name)"
    env: true
    export: false
  }
}

# @type types.Command
let pick_task: record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> = {
  desc: "Pick any task within 1 week (or specifiable) window of the current time."
  group: ""
  aliases: [pt]
  def: {
    name: "pick task"
    params: [
      [key value];
      ["--start(-s)" {type: datetime}]
      ["--end(-e)" {type: datetime}]
    ]
    in: {type: "nothing"}
    out: {type: "nothing"}
    body: $"let timescale = util choose timescale
let now = date now
let chosen = {
  profile_id: ($profile_id_access)
  timescale: $timescale
  start: \($start | default \($now - 1wk\)\)
  end: \($end | default \($now + 1wk\)\)
} | ($fetch_scheduled_pipe) | ($choose_task_pipe)
if $chosen == null { return }
$chosen | ($update_task.def.name)"
    env: true
    export: true
  }
}

# @type types.Command
let progress_log = {
  desc: "Compute the progress log message for the modifications made to tasks."
  group: ""
  aliases: []
  def: {
    name: "progress log"
    params: []
    in: {type: "nothing"}
    out: {type: string}
    body: $"($modified_field | field cmd read name)
| each {|task|
  \"\($task.id\) \($task.state.name\)\"
}
| str join '\n'
    "
    export: false
    env: true
  }
}

# @type types.Form
let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: record<before_cmds: oneof<string, nothing>, after_cmds: oneof<string, nothing>>> = {
  name: progress-update
  params: {
    type: record
    fields: [
      [key value];
      [profile_id {type: int}]
    ]
  }
  returns: {
    type: record
    fields: [
      [key value];
      [modified $modified_list_type]
      [progress_log {type: string}]
    ]
  }
  use: []
  commands: [
    ...($fields | each { field cmds core } | flatten)

    $update_task
    $pick_scheduled
    $pick_task
    $progress_log

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
