# export type Callback = record<expr: string>

# @input closure
# @output Callback
export def "from closure" []: closure -> record<expr: string> {
  # to nuon --serialize will quote the string, so we need to unquote it with
  # "from json"
  {expr: ($in | to nuon --serialize | from json)}
}

# @input nothing
# @output Callback
# @param params list<string>
# @param body string
export def make [params: list<string> body: string]: nothing -> record<expr: string> {
  let params = $params | str join " "
  {
    expr: $"{|($params)| ($body) }"
  }
}

# @input Callback
# @output string
export def run []: record<expr: string> -> string {
  $"do ($in.expr)"
}
