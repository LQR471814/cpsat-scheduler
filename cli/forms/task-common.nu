# @usetype "./lib/gen/types.nu"

use ../lib/proto/apipb/api.gen.nu

# @input nothing
# @output list<string>
export def "required ids" []: nothing -> list<string> {
  [name desc timescale]
}

# @input nothing
# @output list<string>
export def "optional ids" []: nothing -> list<string> {
  [start end prereqs postreqs parent]
}

# @input nothing
# @output types.TypeDef
export def type []: nothing -> oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>> {
  api.gen type TaskState
}

# @input nothing
# @output types.KeyValue<types.TypeDef>
export def "required fields" []: nothing -> record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>> {
  let ids = required ids
  type
  | get fields
  | where key in $ids
}

# @input nothing
# @output types.KeyValue<types.TypeDef>
export def "optional fields" []: nothing -> record<key: string, value: oneof<record<type: string, positional: list<any>>, record<type: string, fields: list<record<key: string, value: any>>>, record<type: string>>> {
  let ids = optional ids
  type
  | get fields
  | where key in $ids
}
