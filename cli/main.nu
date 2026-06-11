# @usetype "./lib/proto/apipb/api.gen.nu"

use lib/proto/apipb/api.gen.nu
use lib/util.nu
use lib/schedule.nu
use lib/profile.nu
use forms/gen/index.nu

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) (do $cmd)" }

def "prompt prefix" []: nothing -> string {
  "(scheduler)"
}

# @input nothing
# @output record<
#   created: list<string>
#   updated: list<string>
#   deleted: list<string>
# >
def "edit profiles" []: nothing -> record<created: list<string>, updated: list<string>, deleted: list<string>> {
  let orig = {}
    | api.gen API ListProfiles
    | get entries
  let new = $orig
    | index form profile-list

  let created = $new
    | where id == null
    | each {
      let prof = $in
      $prof
      | reject id
      | api.gen API CreateProfile
      $prof.name
    }

  let changed = $new
    | where id != null
    | each { {id: $in.id orig: $in} }
    | join --right (
      $orig | each { {id: $in.id new: $in} }
    ) id

  let updated = $changed
    | where new != null

  let deleted = $changed
    | where new == null
    | each {
      let prof = $in
      let delete = util confirm --prompt $"Do you wish to delete profile ($prof.name)?"
      if not $delete { return }
      $prof
      | reject id
      | api.gen API RemoveProfile
      $prof.name
    }

  {
    created: $created
    updated: $updated
    deleted: $deleted
  }
}

def --env "profile switch" []: nothing -> bool {
  let profile_list = {} | api.gen API ListProfiles | get entries
  if ($profile_list | is-empty) {
    edit profiles
    return true
  }

  let profile = $profile_list
    | select id name
    | util choose table --header "Choose profile"
  if $profile == null {
    return false
  }

  $profile.id | profile write
  true
}

def --env "new task" []: nothing -> nothing {
  let task_state = {
    id: null
    profile_id: (profile read)
    state: null
  } | index form task

  if $task_state == null { return }

  {
    id: null
    profile_id: (profile read)
    state: $task_state
  } | api.gen API SaveTask

  schedule recompute
  null
}

def --env "progress update" []: nothing -> nothing {
  {
    prompt_prefix: (prompt prefix)
    state: {profile: (profile read)}
  } | index form progress

  schedule recompute
}

# @input nothing
# @output list<apigen.ListScheduledTasksResponseScheduledTask>
def --env now []: nothing -> list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, duration: oneof<nothing, duration>>> {
  util print label "Current segment (±4 hour period)"
  date now | schedule in segment
}

# @input nothing
# @output list<apigen.ListScheduledTasksResponseScheduledTask>
def --env today []: nothing -> list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, duration: oneof<nothing, duration>>> {
  util print label "Today's tasks"
  date now | schedule in segment
}

# @input nothing
# @output list<apigen.ListScheduledTasksResponseScheduledTask>
def --env tomorrow []: nothing -> list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, duration: oneof<nothing, duration>>> {
  (date now) + 1day | schedule in segment
}

# @input nothing
# @output list<apigen.ListScheduledTasksResponseScheduledTask>
def --env yesterday []: nothing -> list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, duration: oneof<nothing, duration>>> {
  (date now) - 1day | schedule in segment
}

def help []: nothing -> nothing {
  [
    [cmd aliases help];
    [profiles [] "Manage profiles"]
    ['profile switch' [ps] "Switch to a different profile"]
    ['new task' [nt] "Create a task"]
    ['progress update' [pu] "Update task progress"]
    [today [td] "Show today's tasks"]
    [tomorrow [tm] "Show tomorrow's tasks"]
    [yesterday [ys] "Show yesterday's tasks"]
    ['schedule recompute' [re] "Reschedule tasks"]
  ] | table --expand | print
}

if not (profile switch) {
  print exiting!
  exit
}

alias c = exit
alias d = exit
alias ps = profile switch
alias nt = new task
alias pu = progress update
alias td = today
alias tm = tomorrow
alias ys = yesterday
alias re = schedule recompute

help
