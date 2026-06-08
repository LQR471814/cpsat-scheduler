use index.nu
use ../../lib/util.nu
use ../../proto/apipb/api.gen.nu

def --env 'read profile' []: nothing -> list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>>> {
  $env.__state_profile
}

def --env 'write profile' []: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>>> -> nothing {
  $env.__state_profile = $in
}

def 'validate profile' []: nothing -> oneof<string, nothing> {
  read profile | do {||
    if ($in | is-empty) {
      "you must have at least one profile created"
    }
  }
}

def 'add profile' [name: string atomic_timescale: duration universe_start: datetime --pert_choices: int]: nothing -> nothing {
  read profile | append {
    id: null
    name: $name
    atomic_timescale: $atomic_timescale
    universe_start: $universe_start
    gen_pert_choices: $pert_choices
  } | write profile
}

def 'remove profile' []: nothing -> nothing {
  let state = read profile
  let chosen = $state
    | each {|row|
      (
        $row | do {||
          # @type apigen.Profile
          let profile: record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>> = $in
          $profile | select id name
        }
      )
    }
    | util choose table --header 'Remove: List of existing profiles.'
  if $chosen == null { return }
  if not (util confirm --prompt $"Are you sure you wish to remove ($chosen.name)?") { return }
  $state
  | where (
    $it | do {||
      # @type apigen.Profile
      let profile: record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>> = $in
      $profile | select id name
    } | get id
  ) != $chosen.id
  | write profile
}

def 'edit profile' []: nothing -> nothing {
  let state = read profile
    | each {|row|
      {
        row: $row
        entry: (
          $row | do {||
            # @type apigen.Profile
            let profile: record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>> = $in
            $profile | select id name
          }
        )
      }
    }

  let chosen = $state
    | get entry
    | util choose table --header 'Edit: List of existing profiles.'
  if $chosen == null { return }

  let new_row = $state
    | where entry == $chosen
    | get row
    | do {||
      index form profile
    }

  if $new_row == null { return }

  $state
  | each {|row|
    if $in.entry == $chosen { $new_row } else { $row }
  }
  | write profile
}

def 'cancel' []: nothing -> nothing {
  if not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }
  null | util save form output
  exit # nu-lint-ignore: exit_only_in_main
}

def 'done' []: nothing -> nothing {
  let err = read profile | do {||
      if ($in | is-empty) {
        "you must have at least one profile created"
      }
    }
  if $err != null {
    error make $err
  }
  {
    do {|| read profile }
  } | util save form output
  exit
}

def 'status' []: nothing -> nothing {
  util print label 'Profiles [field]'
  util print desc 'List of existing profiles.'
  read profile | {expr: {|| table -e | print }} | print
  let err = do {||
    if ($in | is-empty) {
      "you must have at least one profile created"
    }
  }
  if $err != null {
    util print error $err
  }
  print ''
}

def 'next' []: nothing -> bool {
  if (validate profile) != null {
    do {||
      print "use the 'add profile' command to a profile"
    }
    let err = validate profile
    if $err != null {
      util print error $err
      return false
    }
    return (next)
  }
  return true
}

let __input: record<prompt_prefix: string, params: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>>>> = util get form params

let prompt_prefix: string = $__input.prompt_prefix
let params: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>>> = $__input.params

let default_prompt_prefix: closure = $env.PROMPT_COMMAND
$env.PROMPT_COMMAND = {|| $"($prompt_prefix) \(profile-list\) ($in | do $default_prompt_prefix)" }

$params.profiles | write profile
