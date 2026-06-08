export def 'form profile-list' []: record<prompt_prefix: string, params: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>>>> -> list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>>> {
  util exec form './profile-list.gen.nu' $in
}
