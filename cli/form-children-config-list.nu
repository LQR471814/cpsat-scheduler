use lib/util.nu
use lib/state.nu


let p: record<task: int, children_cfgs: table, prompt_prefix: string> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"($p.prompt_prefix) \(children configs\) ($in | do $cmd)" }

$env.state = []


def "config to string" []: record<desc: int, deadline: record<seconds: int, nanos: int>, exp_cost: int, children: table<id: int, name: string>> -> string { [
    (if ($env.desc | is-not-empty) {
        $env.desc | str substring 0..<12
    } else { null })
    $"cost: ($in.exp_cost)"
    $"children: ($in.children | length)"
] | str join " " }


def "add config" [] {
    util exec form ./form-children-config.nu {

    }
}


def "remove config" []: nothing -> bool {
    let chosen = $env.state | each { config to string } | enumerate | util choose table
    if $chosen != null {
        $env.state = $env.state | drop nth $chosen.id
        return true
    }
    false
}
