# @usetype "./proto/apipb/api.gen.nu"

use util.nu
use proto/apipb/api.gen.nu
use profile.nu

# @input nothing
# @output nothing
export def --env recompute [--start (-s): datetime --end (-e): datetime]: nothing -> nothing {
  let start = $start | default $env.schedule_start? | default (date now) # nu-lint-ignore: check_typed_flag_before_use
  let end = $end | default $env.schedule_end? | default ((date now) + 4wk) # nu-lint-ignore: check_typed_flag_before_use

  # recompute schedule
  let spinner = util spin start
  job spawn {
    try {
      {
        profile: (profile read)
        horizon: {
          start: $start
          end: $end
        }
      } | api.gen API RecomputeSchedule
      $spinner | util spin stop
    } catch {|err|
      $spinner | util spin stop
      error make $err
    }
  }
  $spinner | util spin show 'Recomputing schedule...'
}

# @input datetime
# @output list<apigen.ListScheduledTasksResponseScheduledTask>
export def --env "in segment" []: datetime -> list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, duration: oneof<nothing, duration>>> {
  let time = $in
  {
    profile_id: (profile read)
    timescale: 16
    start: ($time - 4hr)
    end: ($time + 4hr)
  } | api.gen API ListScheduledTasks | get entries
}

# @input datetime
# @output list<apigen.ListScheduledTasksResponseScheduledTask>
export def --env "in date" []: datetime -> list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, duration: oneof<nothing, duration>>> {
  let start_of_day = $in | format date %Y-%m-%d | into datetime
  let end_of_day = $start_of_day + 1day
  {
    profile_id: (profile read)
    timescale: 96
    start: $start_of_day
    end: $end_of_day
  } | api.gen API ListScheduledTasks | get entries
}
