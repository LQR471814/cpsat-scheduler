use ../lib.nu

const script_path = path self | path dirname # nu-lint-ignore: dont_mix_different_effects

let state = [
  [key value];
  [name ({type: string} | lib type optional)]
  [desc ({type: string} | lib type optional)]
  [timescale ({type: int} | lib type optional)]
]

let frontmatter = 'let timescales: table<id: int, name: string> = [[id, name];
	[16, "4 hour"]
    [96, "day"]
    [672, "week"]
    [2688, "month"]
    [8064, "quarter"]
    [32256, "year"]
    [64512, "2 year"]
    [129024, "4 year"]
    [258048, "8 year"]
    [516096, "16 year"]
    [1032192, "32 year"]
    [2064384, "64 year"]
    [4128768, "128 year"]
]'

let form = {
  name: required-fields
  use: (lib form imports)
  frontmatter: $frontmatter
  params: {
    type: record
    fields: $state
  }
  returns: {
    type: record
    fields: $state
  }
  closures: {}
  fields: [
    {
      name: name
      display_name: Name
      type: {type: string}
      closure_bodies: {
        validate: "$env.state.name | is-not-empty"
        getter: "$env.state.name"
        setter: "$env.state.name = $in"
      }
      atomic: {
        closure_bodies: {
          set: "$env.state.name = util input text Name..."
        }
      }
    }
    {
      name: desc
      display_name: Desc
      type: {type: string}
      closure_bodies: {
        validate: "$env.state.desc != null"
        getter: "$env.state.desc"
        setter: "$env.state.desc = $in"
      }
      atomic: {
        closure_bodies: {
          set: "$env.state.desc = util input text Description..."
        }
      }
    }
    {
      name: unit
      display_name: "Timescale unit (bounds maximum duration)"
      type: {type: int}
      closure_bodies: {
        validate: "$env.state.timescale | is-not-empty"
        getter: "$env.state.timescale"
        setter: "$env.state.timescale = $in"
      }
      atomic: {
        closure_bodies: {
          set: "$env.state.timescale = $timescales | util choose table --header 'Timescale unit (bounds maximum duration):' | get id?"
        }
      }
    }
  ]
}

$form | to json --raw
