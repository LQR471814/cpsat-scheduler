use lib/util.nu
use lib/state.nu


let p: record<prompt_prefix: string, id: int, parent: oneof<record<id: int, name: string>, nothing>, start: oneof<record<seconds: int, nanos: int>, nothing>, end: oneof<record<seconds: int, nanos: int>, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>> = util get form params

let cmd = $env.PROMPT_COMMAND
$env.PROMPT_COMMAND = {|| $"($p.prompt_prefix) \(fields\) ($in | do $cmd)" }

$env.state = $p
    | reject prompt_prefix id
    | update start { util from proto time }
    | update end { util from proto time }


def parent []: nothing -> bool {
    let chosen = state list possible relatives PARENT $p.id | util choose table --header "Choose parent"
    if $chosen == null {
        return false
    }
    $env.state.parent = $chosen
    true
}


def "unset parent" []: nothing -> nothing {
    $env.state.parent = null
}


def prereq []: nothing -> bool {
    let chosen = state list possible relatives PREREQ $p.id | util choose table --header "Choose prerequisite task to add:"
    if $chosen == null {
        return false
    }
    $env.state.prereqs ++= $chosen
    true
}


def "remove prereq" []: nothing -> bool {
    let removed = $env.state.prereqs | enumerate | rename | util choose table --header "Choose prerequisite task to remove:"
    if $removed == null {
        return false
    }
    $env.state.prereqs = $env.state.prereqs | where id != $removed.id
    true
}


def postreq []: nothing -> bool {
    let chosen = state list possible relatives POSTREQ $p.id | util choose table --header "Choose postrequisite task to add:"
    if $chosen == null {
        return false
    }
    $env.state.postreqs ++= $chosen
    true
}


def "remove postreq" []: nothing -> bool {
    let removed = $env.state.postreqs | enumerate | rename | util choose table --header "Choose prerequisite task to remove:"
    if $removed == null {
        return false
    }
    $env.state.postreqs = $env.state.postreqs | where id != $removed.id
    true
}


def start []: nothing -> bool {
    let chosen = util choose date
    if $chosen == null {
        return false
    }
    $env.state.start = $chosen
    true
}


def end []: nothing -> bool {
    let chosen = util choose date
    if $chosen == null {
        return false
    }
    $env.state.end = $chosen
    true
}


def status []: nothing -> nothing {
    util print label Parent
    print $env.state.parent
    print ""
    util print label "Prerequisite Tasks"
    print $env.state.prereqs
    print ""
    util print label "Postrequisite Tasks"
    print $env.state.postreqs
    print ""
    util print label "Must start after"
    util print date $env.state.start
    print ""
    util print label "Must end after"
    util print date $env.state.end
    print ""
}


def next []: nothing -> bool {
    if ($env.state.name | is-empty) {
        if not (name) { return false }
        return (next)
    }
    if ($env.state.desc == null) {
        if not (desc) { return false }
        return (next)
    }
    if ($env.state.timescale | is-empty) {
        if not (timescale) { return false }
        return (next)
    }
    status
    true
}


def done []: nothing -> nothing {
    next
    $env.state
        | update start { util to proto time }
        | update end { util to proto time }
        | util save form output
    exit # nu-lint-ignore: exit_only_in_main
}


alias s = status
alias n = next
alias submit = done
alias d = done
