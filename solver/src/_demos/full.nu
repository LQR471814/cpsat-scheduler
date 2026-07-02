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

let tasks = $schedule | get tasks

$tasks
| update start {
  let abs = $in | format date "%Y-%m-%d %H:%M"
  let rel = $in | date humanize
  $"($abs) \(($rel)\)"
}
| group-by unit start --prune
