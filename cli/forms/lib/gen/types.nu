# @usetype "./callback.nu"

# export type TypeDef = oneof<
#   record<
#     type: string,
#     positional: list<any>
#   >
#   record<
#     type: string,
#     fields: list<KeyValue<any>>,
#   >
#   record<
#     type: string,
#   >
# >

# export type KeyValue<T> = record<key: string, value: T>

# export type CommandDef = record<
#   name: string
#   params: list<KeyValue<TypeDef>>
#   body: string
#   in: TypeDef
#   out: TypeDef
#   env: bool
#   export: bool
# >

# export type Command = record<
#   desc: string
#   group: string
#   aliases: list<string>
#   def: CommandDef
# >

# - validate should return string or null
# - init should return the type of the field, it will be called after
# cmds are defined
#
# export type Field = record<
#   id: string
#   display_name: string
#   desc: string
#   group: string
#   type: TypeDef
#   display_value: oneof<callback.Callback, nothing>
#   init: callback.Callback
#	  ops: record<
# 		read: bool
#		  write: bool
#		  validate: oneof<callback.Callback, nothing>
# 	>
# >

# export type Form = record<
#   name: string
#   params: TypeDef
#   returns: TypeDef
#   use: list<string>
#   commands: list<Command>
#   init: record<
#     before_cmds: oneof<string, nothing>
#     after_cmds: oneof<string, nothing>
#   >
# >

# @input TypeDef
# @output TypeDef
export def optional []: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> -> oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> {
  {
    type: oneof
    positional: [
      $in
      {type: "nothing"}
    ]
  }
}

# @input nothing
# @output TypeDef
export def "entry record" []: nothing -> oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> {
  {
    type: record
    fields: [
      [key value];
      [id {type: int}]
      [name {type: string}]
    ]
  }
}

# @input nothing
# @output TypeDef
export def "entry table" []: nothing -> oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> {
  {
    type: table
    fields: [
      [key value];
      [id {type: int}]
      [name {type: string}]
    ]
  }
}

# gets the type of a field in a type with type arguments
#
# @param key string
# @input TypeDef
# @output oneof<TypeDef, nothing>
export def "get field" [key: string]: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> -> oneof<oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>, nothing> {
  get fields | where key == $key | get --optional 0.value?
}

# converts all fields of the given table or record to optional
#
# @input TypeDef
# @output TypeDef
export def "fields optional" []: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> -> oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> {
  # @type TypeDef
  let def: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> = $in
  match $def.type {
    record | table => { }
    _ => {
      error make {
        msg: $"`fields optional` only supports record or table types"
        label: {
          text: value
          span: (metadata $def).span
        }
      }
    }
  }
  $def | update fields { each { update value { optional } } }
}

# @input TypeDef
# @output string
export def render []: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> -> string {
  # @type TypeDef
  let type: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> = $in
  if ($type.fields? | is-not-empty) and ($type.positional? | is-not-empty) {
    error make {
      msg: "type definition cannot have both fields and positional args at the same time!"
      label: {
        text: "input type def"
        span: (metadata $type).span
      }
    }
  }
  let field_args: oneof<string, nothing> = if ($type.fields? | is-not-empty) {
    $type.fields
    | each {|kv|
      $"($kv.key): ($kv.value | render)"
    }
    | str join ", "
  }
  let pos_args: oneof<string, nothing> = if ($type.positional? | is-not-empty) {
    $type.positional
    | each {
      if ($in | describe) == string {
        $type | table --expand | print
      }
      $in | render
    }
    | str join ", "
  }
  let args = if $field_args != null or $pos_args != null {
    $"<(
      if $field_args != null {
        $field_args
      } else if $pos_args != null {
        $pos_args
      }
    )>"
  } else { "" }
  $"($type.type)($args)"
}
