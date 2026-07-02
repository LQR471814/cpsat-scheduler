def "format dt simple" []: datetime -> string {
  format date %H:%M
}

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

let now = date now

let tasks = $schedule
  | get tasks
  | where start <= $now and end >= $now and unit == 4hr

if ($tasks | is-empty) {
  print "nothing to do!"
  exit
}

print $"Block  ($tasks.0.start | format dt simple) -> ($tasks.0.end | format dt simple)"

$tasks | reject start end unit config
