use '../../lib/util.nu'
use '../../lib/proto/apipb/api.gen.nu'
use index.nu

let p: record<prompt_prefix: string, state: record<profile: int, payload: oneof<nothing, record<task: int>, record<parent: oneof<int, nothing>, prereq: oneof<int, nothing>, postreq: oneof<int, nothing>, child: oneof<int, nothing>, >>, >> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state

def "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(task\)"
}

def --env "read req" []: nothing -> record<name: string, desc: string, timescale: int> {
    $env.state | select name desc timescale
}

def --env "set req" []: oneof<record<name: string, desc: string, timescale: int>, nothing> -> nothing {
    let value = $in                                                      
    $env.state = $env.state | merge ($value | select name desc timescale)
}

def --env req []: nothing -> nothing {
    let results = {                           
        prompt_prefix: (prompt prefix)        
        state: (get req)                      
    } | index form required-fields            
    if $results != null { $results | set req }
}

def --env "unset req" []: nothing -> nothing {
    null | set req
}

def --env "read opt" []: nothing -> record<parent: oneof<record<id: int, name: string>, nothing>, start: oneof<datetime, nothing>, end: oneof<datetime, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>> {
    $env.state | select parent start end prereqs postreqs
}

def --env "set opt" []: oneof<record<parent: oneof<record<id: int, name: string>, nothing>, start: oneof<datetime, nothing>, end: oneof<datetime, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>>, nothing> -> nothing {
    let value = $in                                                                    
    $env.state = $env.state | merge ($value | select parent start end prereqs postreqs)
}

def --env "display opt" []: record<parent: oneof<record<id: int, name: string>, nothing>, start: oneof<datetime, nothing>, end: oneof<datetime, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>> -> string {
    table -e
}

def --env opt []: nothing -> nothing {
    let results = {                             
        prompt_prefix: (prompt prefix)          
        state: (get opt | merge { id: $env.id })
    } | index form optional-fields              
    if $results != null { $results | set opt }  
}

def --env "unset opt" []: nothing -> nothing {
    null | set opt
}

def --env "read dur" []: nothing -> oneof<record<pert: record<opt: duration, exp: duration, pes: duration>, deadline: oneof<datetime, nothing>, total_cost: oneof<int, nothing>, >, nothing> {
    $env.state | get duration_cfg
}

def --env "set dur" []: oneof<oneof<record<pert: record<opt: duration, exp: duration, pes: duration>, deadline: oneof<datetime, nothing>, total_cost: oneof<int, nothing>, >, nothing>, nothing> -> nothing {
    $env.state.duration_cfg = $in
}

def --env "display dur" []: oneof<record<pert: record<opt: duration, exp: duration, pes: duration>, deadline: oneof<datetime, nothing>, total_cost: oneof<int, nothing>, >, nothing> -> string {
    table -e
}

def --env dur []: nothing -> nothing {
    if ($env.state.children_cfgs | is-not-empty) {                             
        print 'Cannot set duration configurations when children config is set.'
        return                                                                 
    }                                                                          
    let results = {                                                            
        prompt_prefix: (prompt prefix)                                         
        state: { task: $env.id, cfg: (read dur) }                              
    } | index form duration-config                                             
    if $results != null { $results | set dur }                                 
}

def --env "unset dur" []: nothing -> nothing {
    null | set dur
}

def --env "read children" []: nothing -> table {
    $env.state | get children_cfgs
}

def --env "set children" []: oneof<table, nothing> -> nothing {
    $env.state.children_cfgs = $in
}

def --env "display children" []: table -> string {
    table -e
}

def --env children []: nothing -> nothing {
    if $env.state.duration_cfg? != null {                                      
        print 'Cannot set children configurations when duration config is set.'
        return                                                                 
    }                                                                          
    let results = {                                                            
        prompt_prefix: (prompt prefix)                                         
        state: {                                                               
            task: $env.id                                                      
            children_cfgs: (get children)                                      
        }                                                                      
    } | index form children-config                                             
    if $results != null { $results | set children }                            
}

def --env "unset children" []: nothing -> nothing {
    null | set children
}

def --env status []: nothing -> nothing {
    util print section title 'Form: task'                                      
    util print label 'Required fields'                                         
    print ($env.state | select name desc timescale)                            
    print ""                                                                   
    util print label 'Optional fields'                                         
    print ($env.state | select parent start end prereqs postreqs | display opt)
    print ""                                                                   
    util print label 'Duration configuration'                                  
    print ($env.state | get duration_cfg | display dur)                        
    print ""                                                                   
    util print label 'Children configurations'                                 
    print ($env.state | get children_cfgs | display children)                  
    print ""                                                                   
                                                                               
}

alias s = status
def --env next []: nothing -> bool {
    # nu-lint-ignore: print_and_return_data
    true                                   
}

alias n = next
def cmds []: nothing -> nothing {
    print [[group cmd desc];                                                      
        [common "status, s" "Show form status."]                                  
        [null "next, n" "Fill in next unfilled field."]                           
        [null "submit, done, d" "Submit form."]                                   
        [null "cancel, c" "Abort form."]                                          
        ["req" 'req' 'Interactively set Required fields.']                        
        [null 'write req' 'Set Required fields via nushell command.']             
        [null 'read req' 'Get Required fields via nushell command.']              
        ["opt" 'opt' 'Interactively set Optional fields.']                        
        [null 'write opt' 'Set Optional fields via nushell command.']             
        [null 'read opt' 'Get Optional fields via nushell command.']              
        ["dur" 'dur' 'Interactively set Duration configuration.']                 
        [null 'write dur' 'Set Duration configuration via nushell command.']      
        [null 'read dur' 'Get Duration configuration via nushell command.']       
        ["children" 'children' 'Interactively set Children configurations.']      
        [null 'write children' 'Set Children configurations via nushell command.']
        [null 'read children' 'Get Children configurations via nushell command.'] 
    ]                                                                             
                                                                                  
}

alias h = help
def --env submit []: nothing -> nothing {
    $env.state | util save form output      
    exit # nu-lint-ignore: exit_only_in_main
}

def --env cancel []: nothing -> nothing {
    if not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }
    null | util save form output                                                                           
    exit # nu-lint-ignore: exit_only_in_main                                                               
}

alias done = submit
alias d = submit
alias c = cancel


if $p.state.payload.task? != null {
	$env.state = {id: $p.state.payload.task} | api.gen API ReadTask | get state
	$env.id = $p.state.payload.task
} else {
	let results: record<name: string, desc: oneof<string, nothing>, timescale: int> = {
		prompt_prefix: (prompt prefix)
		state: {
			name: null
			desc: null
			timescale: null
		}
	} | index form required-fields
	if $results == null {
		cancel
	}
	let state = {
		name: $results.name
		desc: $results.desc
		timescale: $results.timescale

		parent: $p.state.payload.parent?
        start: $p.state.payload.start?
        end: $p.state.payload.end?
        prereqs: (if $p.state.payload.prereq? != null { [$p.state.payload.prereq] } else { [] })
        postreqs: (if $p.state.payload.postreq? != null { [$p.state.payload.postreq] } else { [] })

		duration_cfg: {
			pert: {
				opt: 30min
				exp: 1hr
				pes: (1hr + 30min)
			}
			deadline: null
            total_cost: 0
        }
        children_cfgs: []
	}
	let id = {id: null, profile_id: $p.state.profile, state: $state} | api.gen API SaveTask | get id
	$env.state = $state
	$env.id = $id
}
	

