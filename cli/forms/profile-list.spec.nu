# @usetype "./lib/gen/types.nu"
# @usetype "./lib/gen/form.nu"
# @usetype "../lib/proto/apipb/api.gen.nu"

use ./lib/gen/form.nu
use ./lib/gen/field.nu
use ./lib/gen/callback.nu
use ../lib/proto/apipb/api.gen.nu

# @type types.Field
let profiles_field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>> = {
  id: profile
  display_name: Profiles
  desc: "List of existing profiles."
  group: field
  type: {type: list positional: [(api.gen type Profile)]}
  display_value: null
  ops: {
    read: true
    write: true
    validate: (
      {||
        if ($in | is-empty) {
          "you must have at least one profile created"
        }
      } | callback from closure
    )
  }
}

# @type list<types.Field>
let fields: list<record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>> = [
  $profiles_field
]

# @type types.Command
let add_profile: record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>> = {
  desc: "add a new profile"
  group: field
  aliases: [ap]
  def: {
    name: "add profile"
    params: [
      [key value];
      [name {type: string}]
      [atomic_timescale {type: duration}]
      [universe_start {type: datetime}]
      [--pert_choices {type: int}]
    ]
    in: {type: "nothing"}
    out: {type: "nothing"}
    body: $"($profiles_field | field cmd read name) | append {
	id: null
	name: $name
	atomic_timescale: $atomic_timescale
	universe_start: $universe_start
	gen_pert_choices: $pert_choices
} | ($profiles_field | field cmd write name)"
    env: true
    export: false
  }
}

# @type list<form.InteractiveField>
let fields_ordering: list<record<field: record<id: string, display_name: string, desc: string, group: string, type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, display_value: oneof<record<expr: string>, nothing>, ops: record<read: bool, write: bool, validate: oneof<record<expr: string>, nothing>>>, interact: record<expr: string>>> = [
  {
    field: $profiles_field
    interact: (
      {||
        print "use the 'add profile' command to a profile"
      } | callback from closure
    )
  }
]

# @type types.Form
let form: record<name: string, params: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, returns: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, use: list<string>, commands: list<record<desc: string, group: string, aliases: list<string>, def: record<name: string, params: list<record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>>>, body: string, in: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, out: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, env: bool, export: bool>>>, init: oneof<string, nothing>> = {
  name: profile-list
  params: $profiles_field.type
  returns: $profiles_field.type
  use: []
  commands: [
    ...($fields | each { field cmds core } | flatten)

    $add_profile
    (
      $profiles_field | field cmd interact list remove (
        {||
          # @type apigen.Profile
          let profile: record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>> = $in
          $profile | select id name
        } | callback from closure
      )
    )
    (
      $profiles_field | field cmd interact list edit (
        {||
          # @type apigen.Profile
          let profile: record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>> = $in
          $profile | select id name
        } | callback from closure
      ) (
        {||
          index form profile
        } | callback from closure
      )
    )

    (form cmd cancel)
    ($fields | form cmd done --output (callback make [] $"($profiles_field | field cmd read name)"))
    ($fields | form cmd status)
    ($fields_ordering | form cmd next)
  ]
  init: $"
$params | ($profiles_field | field cmd write name)
	"
}

$form | to nuon --raw
