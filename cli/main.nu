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
  let res = index form progress-update
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
  date now | schedule in date
}

# @input nothing
# @output list<apigen.ListScheduledTasksResponseScheduledTask>
def --env tomorrow []: nothing -> list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, duration: oneof<nothing, duration>>> {
  (date now) + 1day | schedule in date
}

# @input nothing
# @output list<apigen.ListScheduledTasksResponseScheduledTask>
def --env yesterday []: nothing -> list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, duration: oneof<nothing, duration>>> {
  (date now) - 1day | schedule in date
}

def cmds []: nothing -> nothing {
  [
    [cmd aliases help];
    ["edit profiles" [] "Manage profiles"]
    ["profile switch" [ps] "Switch to a different profile"]
    ["new task" [nt] "Create a task"]
    ["progress update" [pu] "Update task progress"]
    [today [td] "Show today's tasks"]
    [tomorrow [tm] "Show tomorrow's tasks"]
    [yesterday [ys] "Show yesterday's tasks"]
    ["schedule recompute" [re] "Reschedule tasks"]
    ["widen var factor" [] "Increase/decrease a range's variability by a factor (ex. 2x)."]
    ["widen var" [] "Increase a range's variability."]
    ["shrink var" [] "Decrease a range's variability."]
    ["add dur" [] "Increase a range's estimated duration without changing variability."]
    ["sub dur" [] "Decrease a range's estimated duration without changing variability."]
  ] | update aliases { str join ", " } | table --expand | print
}

# type PERT = record<pes: duration, exp: duration, opt: duration>

# @input nothing
# @output oneof<int, nothing>
def "pick task" []: nothing -> oneof<int, nothing> {
  {profile: (profile read)}
  | api.gen API ListTasks
  | get tasks
  | util choose table --header "Choose a task (last modified at the top):"
  | get id?
}

# @input int
# @output apigen.TaskState
def "show task" []: int -> record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>>>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>> {
  {id: $in} | api.gen API ReadTask | get state | table --expand
}

# @input oneof<int, nothing>
# @output nothing
def "edit task" []: oneof<int, nothing> -> nothing {
  let id = $in
  if $id == null { return }

  let result = {id: $id}
    | api.gen API ReadTask
    | merge {id: $id}
    | index form task
  if $result == null { return }
  {
    id: $id
    profile_id: (profile read)
    state: $result
  }
  | api.gen API SaveTask
  null
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

def "scale pert factor" [factor: float] {
  update pert headless {|| util range scale $factor }
}

def "widen pert percent" [percent_delta: float] {
  update pert headless {|| util range widen percent $percent_delta }
}

def "widen pert amount" [amount: duration] {
  update pert headless {|| util range widen amount $amount }
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

def "widen var factor" [factor: float]: oneof<nothing, int> -> oneof<nothing, int> {
  let task = $in | default { pick task }
  if $task == null { return }
  $task | scale pert factor $factor
  $task
}

def "widen var" [value: oneof<string, duration>]: oneof<nothing, int> -> oneof<nothing, int> {
  let task: oneof<int, nothing> = $in | default { pick task }
  if $task == null { return }

  match ($value | describe) {
    duration => {
      $task | widen pert amount $value
    }
    string => {
      let value = $value | parse percent
      $task | widen pert percent $value
    }
  }

  $task
}

def "shrink var" [value: oneof<duration, string>]: oneof<nothing, int> -> oneof<int, nothing> {
  let task: oneof<int, nothing> = $in | default { pick task }
  if $task == null { return }
  match ($value | describe) {
    duration => {
      let value: duration = $value
      $task | widen pert amount (-1 * $value)
    }
    string => {
      let value = $value | parse percent
      $task | widen pert percent (-1 * $value)
    }
  }
  $task
}

# expand pert 45%
# expand pert 30min
def "add dur" [amount: oneof<string, duration>]: oneof<nothing, int> -> oneof<int, nothing> {
  let task = $in | default { pick task }
  if $task == null { return }

  match ($amount | describe) {
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

  $task
}

# shrink pert 45%
# shrink pert 30min
def "sub dur" [amount: oneof<string, duration>]: oneof<nothing, int> -> oneof<int, nothing> {
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

  $task
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
