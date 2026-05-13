use lib/util.nu


use lib/state.nu


let p: record<prompt_prefix: string, task: oneof<int, nothing>, profile: int> = util get form params


def "prompt status" []: nothing -> string {
    if $env.id {
        $"task - ($env.id)"
    } else {
        "new task"
    }
}


def "prompt prefix" []: nothing -> string { $"($p.prompt_prefix) \((prompt status)\)" }


let cmd = $env.PROMPT_COMMAND


$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }


def "ensure task" []: nothing -> nothing {
    if $p.task != null {
        load-env {
			id: $p.task
			state: (state read task $p.task | get state)
		}
        return
    }
    let results = util exec form ./form-task-fields.nu {
        prompt_prefix: (prompt prefix)
        name: null
        desc: null
        timescale: null
        parent: null
        start: null
        end: null
        prereqs: []
        postreqs: []
    }
    let state = {
        duration_cfg: {
            opt: 2
            exp: 4
            pes: 6
            total_cost: 0
        }
        children_cfgs: []
    } | merge $results
    let id: int = state save task $p.profile $state | get id
    load-env {
		state: $state
		id: $id
	}
}


def "edit task" []: nothing -> nothing {
    let existing = state read task $p.task | get state
    let results = util exec form ./form-task-main.nu ($env.state | reject duration_cfg children_cfgs)
    $env.state = $existing | merge $results
}


def "delete task" []: nothing -> nothing {
    state delete task $env.id
    null
}


def "save task" []: nothing -> nothing {
    if ($env.state.children_cfgs | is-empty) and ($env.state.duration_cfg == null) {
        print "cannot save task: no children configs specified and no duration config specified"
        return
    }
    exit # nu-lint-ignore: exit_only_in_main
}


def "set dur cfg" []: nothing -> nothing { }


def "unset dur cfg" []: nothing -> nothing { $env.state.duration_cfg = null }


def "new child cfg" []: nothing -> nothing { }


def "del child cfg" []: nothing -> nothing { }


def status [] { }


# combined form:
# - force task prompt if not already exist -> task exist
# - actions: status || edit task || set/unset dur config || new/delete child config || delete task || save task
# - set dur config -> dur config form
# - new child config -> child config form
ensure task


alias cancel = delete task
alias s = status
alias submit = save task
alias done = save task
alias d = save task
