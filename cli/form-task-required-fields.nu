use lib/util.nu
use lib/state.nu


# form parameters (only one of these can be set)
let p: record<prompt_prefix: string, id: oneof<int, nothing>, name: oneof<string, nothing>, desc: string, timescale: oneof<int, nothing>, > = util get form params


let cmd = $env.PROMPT_COMMAND


$env.PROMPT_COMMAND = {|| $"($p.prompt_prefix) \(fields\) ($in | do $cmd)" }


let timescales: table<id: int, name: string> = [[id, name];
    [96, "day"]
    [672, "week"]
    [2688, "month"]
    [8064, "quarter"]
    [32256, "year"]
    [64512, "2 year"]
    [129024, "4 year"]
    [258048, "8 year"]
    [516096, "16 year"]
    [1032192, "32 year"]
    [2064384, "64 year"]
    [4128768, "128 year"]
]


def name []: nothing -> bool {
    $env.state.name = util input text Name...
    $env.state.name | is-not-empty
}


def desc []: nothing -> bool {
    $env.state.desc = util input multiline Description...
    $env.state.name != null
}


def timescale []: nothing -> bool {
    $env.state.timescale = $timescales | util choose table --header "Timescale unit:" | get id?
    $env.state.timescale != null
}


def status []: nothing -> nothing {
    util print section title Required
    util print label Name
    print $env.state.name
    print ""
    util print label Description
    print $env.state.desc
    print ""
    util print label Unit
    print $env.state.timescale
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
    $env.state | util save form output
    exit # nu-lint-ignore: exit_only_in_main
}


alias unit = timescale
alias s = status
alias n = next
alias submit = done
alias d = done
