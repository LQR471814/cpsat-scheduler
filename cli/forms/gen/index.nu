use ../../lib/util.nu
export def "form profiles" []: record<prompt_prefix: string, state: nothing> -> nothing {
	util exec form "./forms/gen/profiles.gen.nu" $in
}
export def "form child-config" []: record<prompt_prefix: string, state: record<task: int, desc: oneof<string, nothing>, deadline: oneof<string, nothing>, exp_cost: oneof<int, nothing>, children: table<id: int, name: string>>> -> record<task: int, desc: oneof<string, nothing>, deadline: oneof<string, nothing>, exp_cost: oneof<int, nothing>, children: table<id: int, name: string>> {
	util exec form "./forms/gen/child-config.gen.nu" $in
}
export def "form children-config" []: record<prompt_prefix: string, state: record<task: int, children_cfgs: table>> -> table {
	util exec form "./forms/gen/children-config.gen.nu" $in
}
export def "form duration-config" []: record<prompt_prefix: string, state: record<task: oneof<int, nothing>, cfg: oneof<record<pert: record<opt: string, exp: string, pes: string>, deadline: oneof<string, nothing>, total_cost: int>, nothing>, >> -> oneof<record<pert: record<opt: string, exp: string, pes: string>, deadline: oneof<string, nothing>, total_cost: int>, nothing> {
	util exec form "./forms/gen/duration-config.gen.nu" $in
}
export def "form optional-fields" []: record<prompt_prefix: string, state: record<id: oneof<int, nothing>, parent: oneof<record<id: int, name: string>, nothing>, start: oneof<string, nothing>, end: oneof<string, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>>> -> record<id: oneof<int, nothing>, parent: oneof<record<id: int, name: string>, nothing>, start: oneof<string, nothing>, end: oneof<string, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>> {
	util exec form "./forms/gen/optional-fields.gen.nu" $in
}
export def "form required-fields" []: record<prompt_prefix: string, state: record<name: oneof<string, nothing>, desc: oneof<string, nothing>, timescale: oneof<int, nothing>, >> -> record<name: oneof<string, nothing>, desc: oneof<string, nothing>, timescale: oneof<int, nothing>, > {
	util exec form "./forms/gen/required-fields.gen.nu" $in
}
export def "form task" []: record<prompt_prefix: string, state: record<profile: int, payload: oneof<record<task: int>, record<parent: oneof<int, nothing>, prereq: oneof<int, nothing>, postreq: oneof<int, nothing>, child: oneof<int, nothing>, >>, >> -> record<profile: int, payload: oneof<record<task: int>, record<parent: oneof<int, nothing>, prereq: oneof<int, nothing>, postreq: oneof<int, nothing>, child: oneof<int, nothing>, >>, > {
	util exec form "./forms/gen/task.gen.nu" $in
}
