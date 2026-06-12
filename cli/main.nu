# @usetype "./lib/proto/apipb/api.gen.nu"

use lib/proto/apipb/api.gen.nu
use lib/util.nu
use lib/schedule.nu
use lib/profile.nu
use forms/gen/index.nu

let cmd = $env.PROMPT_COMMAND

$env.prompt_prefix = {|| "(scheduler)" }
$env.PROMPT_COMMAND = {|| $"(do $env.prompt_prefix) (do $cmd)" }

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
    | par-each {
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

    {}
    | api.gen API ListProfiles
    | get entries
    | first
    | get id
    | profile write

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
  let res = {profile_id: (profile read)}
    | index form progress-update
  if $res == null { return }

  let updated: list<int> = $res.modified | get id
  {
    profile: (profile read)
    time: (date now)
    updated_tasks: $updated
  } | api.gen API ProgressUpdate

  $res.modified
  | par-each {|row|
    {
      profile_id: (profile read)
      id: $row.id
      state: $row.state
    } | api.gen API SaveTask
  }

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

def cmds []: nothing -> nothing {
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
    ['scale pert' [] "Set a task's PERT range to a percentage of its current values."]
    ['widen pert' [] "Widen a task's PERT range by a percentage."]
    ['shrink pert' [] "Shrink a task's PERT range by a percentage."]
    ['add pert' [] "Add a task's PERT range by a percent or duration."]
    ['sub pert' [] "Subtract from a task's PERT range by a percent or duration."]
  ] | update aliases { str join ", " } | table --expand | print
}

# type PERT = record<pes: duration, exp: duration, opt: duration>

# @input nothing
# @output oneof<apigen.Entry, nothing>
def "pick task" []: nothing -> oneof<record<id: oneof<nothing, int>, name: oneof<nothing, string>>, nothing> {
  {profile: (profile read)}
  | api.gen API ListTasks
  | get tasks
  | util choose table --header "Choose a task (last modified at the top):"
}

# @input int
# @output nothing
#
# update takes in a PERT range and returns a PERT range
def "update pert headless" [update: closure]: int -> nothing {
  let task: int = $in
  let state = {id: $task} | api.gen API ReadTask | get state
  let updated = $state
    | update duration_cfg.pert $update
  {
    id: $task
    profile_id: (profile read)
    state: $updated
  } | api.gen API SaveTask
  null
}

# @input oneof<nothing, int>
# @output nothing
def "set pert" [pes: duration exp: duration opt: duration]: oneof<nothing, int> -> nothing {
  let task: oneof<int, nothing> = $in | default { pick task }
  if $task == null { return }
  $task | update pert headless {|| {pes: $pes exp: $exp opt: $opt} }
}

def "scale pert percent" [percent_delta: float] {
  update pert headless {|| util range scale $percent_delta }
}

def "widen pert percent" [percent_delta: float] {
  update pert headless {|| util range widen $percent_delta }
}

def "shift pert duration" [amount: duration]: int -> nothing {
  update pert headless {|| util range shift amount $amount }
}

def "shift pert percent" [percent: float]: int -> nothing {
  update pert headless {|| util range shift percent $percent }
}

def "parse percent" []: string -> float {
  parse --regex `(?<value>[\d.]+)%`
  | get value.0
  | into float
}

def "scale pert" [percent: string]: oneof<nothing, int> -> nothing {
  let task: oneof<int, nothing> = $in | default { pick task }
  if $task == null { return }
  let percent = $percent | parse percent
  $task | scale pert percent $percent
}

def "expand pert" [percent: string]: oneof<nothing, int> -> nothing {
  let task: oneof<int, nothing> = $in | default { pick task }
  if $task == null { return }
  let percent = $percent | parse percent
  $task | widen pert percent $percent
}

def "shrink pert" [percent: string]: oneof<nothing, int> -> nothing {
  let task: oneof<int, nothing> = $in | default { pick task }
  if $task == null { return }
  let percent = $percent | parse percent
  $task | widen pert percent (-1 * $percent)
}

# expand pert 45%
# expand pert 30min
def "add pert" [amount: oneof<string, duration>]: oneof<nothing, int> -> nothing {
  let task = $in | default { pick task }
  if $task == null { return }

  match $amount {
    string => {
      $task | shift pert percent ($amount | parse percent)
    }
    duration => {
      let amount: duration = $amount
      $task | shift pert duration $amount
    }
    _ => {
      error make {
        msg: $"unsupported type ($amount | describe)"
        label: {
          text: value
          span: (metadata $amount).span
        }
      }
    }
  }
}

# shrink pert 45%
# shrink pert 30min
def "sub pert" [amount: oneof<string, duration>]: oneof<nothing, int> -> nothing {
  let task: oneof<int, nothing> = $in | default { pick task }
  if $task == null { return }

  match $amount {
    string => {
      $task | shift pert percent (-1 * ($amount | parse percent))
    }
    duration => {
      let amount: duration = $amount
      $task | shift pert duration (-1 * $amount)
    }
    _ => {
      error make {
        msg: $"unsupported type ($amount | describe)"
        label: {
          text: value
          span: (metadata $amount).span
        }
      }
    }
  }
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
alias pt = pick task

cmds
