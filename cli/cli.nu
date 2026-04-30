use ./lib/db.nu

# 1. method to create task (list of preset constants)
# 2. method to edit / delete task
# 3.1. method to view current timescale instance of a given unit in current schedule
# 3.2. method to view child timescale instances of a given timescale
# 4. method to sync events from caldav
# 5. schedule recomputation should happen automatically

let state = db load

$state | query db "select * from task"


