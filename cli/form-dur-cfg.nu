use lib/util.nu


use lib/state.nu


let p: record<prompt_prefix: string, task: int, cfg: oneof<record<opt: record<seconds: int, nanos: int>, exp: record<seconds: int, nanos: int>, pes: record<seconds: int, nanos: int>, deadline: record<seconds: int, nanos: int>, total_cost: int>, nothing>, > = util get form params


def "prompt prefix" []: nothing -> string { $"($p.prompt_prefix) \(duration config\)" }


let cmd = $env.PROMPT_COMMAND


$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }


$env.cfg = $p.cfg


def deadline [--date(-d): datetime]: nothing -> bool {
    if $date != null {
        $env.deadline = $date
        return true
    }
    $env.cfg.deadline = util choose date
    $env.cfg.deadline != null
}


def cost [--value(-v): int]: nothing -> bool {
    # nu-lint-ignore: print_and_return_data
    if $value != null {
        $env.cfg.cost = $value
        return true
    }
    $env.cfg.cost = util input int "Cost... (integer)"
    $env.cfg.cost != null
}


def pert [...values: duration]: nothing -> nothing {
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
    $env.cfg.opt = $values.0
    $env.cfg.exp = $values.1
    $env.cfg.pes = $values.2
}


def status [] {
    util print label Deadline
    if $env.cfg.deadline != null {
        util print date $env.cfg.deadline
    }
    print ""
    util print label Cost
    print $env.cfg.cost
    print ""
    util print label Optimistic
    util print duration $env.cfg.opt
    print ""
    util print label Expected
    util print duration $env.cfg.exp
    print ""
    util print label Pessimistic
    util print duration $env.cfg.pes
    print ""
}


def done []: nothing -> nothing {
    next
    $env.state | update opt { util to proto time } | update exp { util to proto time } | update pes { util to proto time } | util save form output
    exit # nu-lint-ignore: exit_only_in_main
}
