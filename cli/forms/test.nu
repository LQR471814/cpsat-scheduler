use ./lib/nav.nu
use ../lib/proto/apipb/api.gen.nu
use ./gen/index.nu

let result = {
  prompt_prefix: "(main)"
  params: ({} | api.gen API ListProfiles | get entries)
} | index form profile-list

$result | table -e | print
