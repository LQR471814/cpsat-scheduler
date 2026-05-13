use lib/util.nu


use lib/state.nu


let p: record<prompt_prefix: string, task_id: int> = util get form params


const DURATION_TYPE = "duration"


const CHILDREN_TYPE = "children"


let types: table<id: int, name: string> = [$DURATION_TYPE, $CHILDREN_TYPE] | enumerate | rename id name


def "active type" []: nothing -> bool {
    $env.active_config_type = $types | util choose table --header "Task type:" | get name
    $env.active_config_type | is-not-empty
}


def deadline [--date(-d): datetime]: nothing -> bool {
    if $date != null {
        $env.deadline = $date
        return true
    }
    $env.deadline = util choose date
    $env.deadline != null
}


def cost [--value(-v): int]: nothing -> bool {
    # nu-lint-ignore: print_and_return_data
    if $value != null {
        $env.cost = $value
        return true
    }
    if $env.active_config_type? != $DURATION_TYPE {
        print "note: task was automatically changed to duration type"
        $env.active_config_type = $DURATION_TYPE
    }
    if ($env.deadline? | is-empty) and not (deadline) {
        return false
    }
    $env.dur_cost = util input int "Cost... (integer)"
    $env.dur_cost != null
}


def pert [...values: duration]: nothing -> nothing {
    if $env.active_config_type? != $DURATION_TYPE {
        $env.active_config_type = $DURATION_TYPE
    }
    if ($values | length) != 3 {
        error make {
            msg: "missing arguments: <optimistic> <expected> <pessimistic>"
            labels: [
                {
                    text: "incorrect # of values"
                    span: (metadata $values).span
                }
            ]
        }
    }
    $env.dur_pert = $values
}


def status [] {
    util print label Deadline
    print (if $env.deadline? {
        $env.deadline | format date %Y-%m-%d
    })
    print ""
}
