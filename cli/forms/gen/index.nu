export def 'form profiles' []: record<prompt_prefix: string, params: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>>>> -> nothing {
util exec form './profiles.gen.nu' $in
}
