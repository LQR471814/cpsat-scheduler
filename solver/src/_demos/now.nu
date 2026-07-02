let schedule = open schedule.json
  | update tasks {
    each {|t|
      $t
      | update start { into datetime }
      | update end { into datetime }
      | update duration { $in * 1sec }
      | update unit { $in * 1sec }
    }
  }

let start = date now

$schedule
| get tasks
| where $start >= $it.start and unit == 4hr
