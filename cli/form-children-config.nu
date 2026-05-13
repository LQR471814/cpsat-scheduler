use lib/util.nu


use lib/state.nu


let p: record<task: int, prompt_prefix: string> = util get form params


let cmd = $env.PROMPT_COMMAND


$env.PROMPT_COMMAND = {|| $"($p.prompt_prefix) \(edit\) ($in | do $cmd)" }


$env.state = {
    desc: null
    deadline: null
    exp_cost: null
    children: []
}


def desc []: nothing -> bool {
    $env.state.desc = util input multiline Description...
    $env.state.desc != null
}


def "add child" []: nothing -> bool {
    let child: oneof<int, nothing> = state list possible relatives CHILD $p.task | util choose table --header "Choose child to add:"
    if $child == null {
        return false
    }
    $env.state.children ++= $child
    true
}


def "remove child" []: nothing -> bool {
    let child = $env.state.children | util choose table --header "Choose child to remove:"
    if $child == null {
        return false
    }
    $env.state.children = $env.state.children | where id != $child.id
    true
}


def deadline [--date(-d): datetime]: nothing -> bool {
    if $date != null {
        $env.state.deadline = $date
        return true
    }
    $env.state.deadline = util choose date
    $env.state.deadline != null
}


def cost [--value(-v): int]: nothing -> bool {
    if $value != null {
        $env.state.cost = $value
        return true
    }
    if ($env.state.deadline | is-empty) and not (deadline) {
        return false
    }
    $env.state.exp_cost = util input int "Cost... (integer)"
    $env.state.exp_cost != null
}


def status []: nothing -> nothing {
    util print label Desc
    print $env.state.desc
    print ""
    util print label Deadline
    print (if $env.state.deadline != null {
        $env.state.deadline | format date %Y-%m-%d
    })
    print ""
    util print label "Expected Cost"
    print ($env.state.cost)
    print ""
    util print label Children
    print $env.state.children
    print ""
}


def next []: nothing -> bool {
    # nu-lint-ignore: print_and_return_data
    if $env.state.desc == null {
        if not (desc) { return false }
        return (next)
    }
    if $env.state.deadline == null {
        if not (deadline) { return false }
        return (next)
    }
    if $env.state.cost == null {
        if not (cost) { return false }
        return (next)
    }
    if ($env.state.children | is-empty) {
        print "add children with `add child`"
        return false
    }
    true
}


def submit []: nothing -> nothing {
    next
    let output = {
        desc: $env.state.desc
        deadline: $env.state.deadline
        exp_cost: $env.state.exp_cost
        children: $env.state.children
    }
    $output | util save form output
    exit # nu-lint-ignore: exit_only_in_main
}
