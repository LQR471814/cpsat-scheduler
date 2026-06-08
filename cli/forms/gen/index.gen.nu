use ../../lib/util.nu
export def "form profiles" []: record<prompt_prefix: string, state: nothing> -> nothing {
  util exec form "./forms/gen/profiles.gen.nu" $in
}
export def "form progress" []: record<prompt_prefix: string, state: record<profile: int>> -> nothing {
  util exec form "./forms/gen/progress.gen.nu" $in
}
export def "form child-config" []: record<prompt_prefix: string, state: record<task: int, desc: oneof<string, nothing>, deadline: oneof<datetime, nothing>, exp_cost: oneof<int, nothing>, children: table<id: int, name: string>>> -> record<task: int, desc: oneof<string, nothing>, deadline: oneof<datetime, nothing>, exp_cost: oneof<int, nothing>, children: table<id: int, name: string>> {
  util exec form "./forms/gen/child-config.gen.nu" $in
}
export def "form children-config" []: record<prompt_prefix: string, state: record<task: int, children_cfgs: table>> -> table {
  util exec form "./forms/gen/children-config.gen.nu" $in
}
export def "form duration-config" []: record<prompt_prefix: string, state: record<task: oneof<int, nothing>, cfg: oneof<record<pert: record<opt: duration, exp: duration, pes: duration>, deadline: oneof<datetime, nothing>, total_cost: oneof<int, nothing>>, nothing>>> -> oneof<record<pert: record<opt: duration, exp: duration, pes: duration>, deadline: oneof<datetime, nothing>, total_cost: oneof<int, nothing>>, nothing> {
  util exec form "./forms/gen/duration-config.gen.nu" $in
}
export def "form optional-fields" []: record<prompt_prefix: string, state: record<id: oneof<int, nothing>, parent: oneof<record<id: int, name: string>, nothing>, start: oneof<datetime, nothing>, end: oneof<datetime, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>>> -> record<id: oneof<int, nothing>, parent: oneof<record<id: int, name: string>, nothing>, start: oneof<datetime, nothing>, end: oneof<datetime, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>> {
  util exec form "./forms/gen/optional-fields.gen.nu" $in
}
export def "form required-fields" []: record<prompt_prefix: string, state: record<name: oneof<string, nothing>, desc: oneof<string, nothing>, timescale: oneof<int, nothing>>> -> record<name: oneof<string, nothing>, desc: oneof<string, nothing>, timescale: oneof<int, nothing>> {
  util exec form "./forms/gen/required-fields.gen.nu" $in
}
export def "form task" []: record<prompt_prefix: string, state: record<profile: int, payload: oneof<nothing, record<task: int>, record<parent: oneof<int, nothing>, prereq: oneof<int, nothing>, postreq: oneof<int, nothing>, child: oneof<int, nothing>>>>> -> oneof<nothing, record> {
  util exec form "./forms/gen/task.gen.nu" $in
}
export def "form task-update" []: record<prompt_prefix: string, state: record<profile: int>> -> oneof<nothing, record<task_id: int, task_state: record, progress_log: string>> {
  util exec form "./forms/gen/task-update.gen.nu" $in
}
