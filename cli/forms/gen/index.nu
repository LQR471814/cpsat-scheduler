use ../lib/nav.nu

const form_dir = path self ../gen

export def --env "form task-required" []: record<name: oneof<string, nothing>, desc: oneof<string, nothing>, timescale: oneof<int, nothing>> -> record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>> {
nav exec form ($form_dir | path join "task-required.spec.gen.nu") $in
}

export def --env "form task-child-config" []: record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, task_id: int> -> record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>> {
nav exec form ($form_dir | path join "task-child-config.spec.gen.nu") $in
}

export def --env "form task-children-configs" []: record<task_id: int, children: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>> -> list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>> {
nav exec form ($form_dir | path join "task-children-configs.spec.gen.nu") $in
}

export def --env "form profile-list" []: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>>> -> list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>>> {
nav exec form ($form_dir | path join "profile-list.spec.gen.nu") $in
}

export def --env "form task-optional" []: record<prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, nothing>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, task_id: int> -> record<prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>> {
nav exec form ($form_dir | path join "task-optional.spec.gen.nu") $in
}

export def --env "form task-duration" []: oneof<record<pert: oneof<oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, nothing>, deadline: oneof<oneof<nothing, datetime>, nothing>, total_cost: oneof<oneof<nothing, int>, nothing>>, nothing> -> record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>> {
nav exec form ($form_dir | path join "task-duration.spec.gen.nu") $in
}

export def --env "form task" []: record<state: oneof<record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>>>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>>, nothing>, id: oneof<int, nothing>, profile_id: int> -> record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>>>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>> {
nav exec form ($form_dir | path join "task.spec.gen.nu") $in
}

export def --env "form progress-update" []: record<profile_id: int> -> record<modified: list<record<id: int, state: record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>>>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>>>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>>>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>>>>, progress_log: string> {
nav exec form ($form_dir | path join "progress-update.spec.gen.nu") $in
}