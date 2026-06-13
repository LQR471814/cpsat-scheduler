use ./gen/index.nu

$env.prompt_prefix = {|| "(main)" }

$env.cpsat-profile = 1

{
  id: null
  state: {
    name: null
    desc: null
    timescale: null
    duration_cfg: null
    children_cfgs: []
    prereqs: []
    postreqs: []
    parent: null
    start: null
    end: null
  }
} | index form task
