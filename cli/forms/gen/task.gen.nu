use '../../lib/util.nu'
use '../../lib/api.gen.nu'
use index.nu

let p: record<prompt_prefix: string, state: record<profile: int, payload: oneof<nothing, record<task: int>, record<parent: oneof<int, nothing>, prereq: oneof<int, nothing>, postreq: oneof<int, nothing>, child: oneof<int, nothing>, >>, >> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state

def --env "returns post process" []: any -> record<id: int> {
    let input = $in | get payload                                       
    {profile_id: $p.state.profile, state: $input} | api.gen API SaveTask
}

def "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(task\)"
}

def --env "get req" []: nothing -> record<name: string, desc: string, timescale: int> {
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

def --env "get opt" []: nothing -> record<parent: oneof<record<id: int, name: string>, nothing>, start: oneof<string, nothing>, end: oneof<string, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>> {
    $env.state | select parent start end prereqs postreqs
}

def --env "set opt" []: oneof<record<parent: oneof<record<id: int, name: string>, nothing>, start: oneof<string, nothing>, end: oneof<string, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>>, nothing> -> nothing {
    let value = $in                                                                    
    $env.state = $env.state | merge ($value | select parent start end prereqs postreqs)
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

def --env "get dur" []: nothing -> oneof<record<pert: record<opt: string, exp: string, pes: string>, deadline: oneof<string, nothing>, total_cost: int>, nothing> {
    $env.state | get duration_cfg
}

def --env "set dur" []: oneof<oneof<record<pert: record<opt: string, exp: string, pes: string>, deadline: oneof<string, nothing>, total_cost: int>, nothing>, nothing> -> nothing {
    $env.state.duration_cfg = $in
}

def --env dur []: nothing -> nothing {
    let results = {                             
        prompt_prefix: (prompt prefix)          
        state: { task: $env.id, cfg: (get dur) }
    } | index form duration-config              
    if $results != null { $results | set dur }  
}

def --env "unset dur" []: nothing -> nothing {
    null | set dur
}

def --env "get children" []: nothing -> table {
    $env.state | get children_cfgs
}

def --env "set children" []: oneof<table, nothing> -> nothing {
    $env.state.children_cfgs = $in
}

def --env children []: nothing -> nothing {
    let results = {                                     
        prompt_prefix: (prompt prefix)                  
        state: {                                        
            task: $env.id                               
            children_cfgs: (get children)               
        }                                               
    } | index form children-config                      
    if $results != null { $results | set children_cfgs }
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
    print ($env.state | select parent start end prereqs postreqs)
    print ""                                                     
    util print label 'Duration configuration'                    
    print ($env.state | get duration_cfg)                        
    print ""                                                     
    util print label 'Children configurations'                   
    print ($env.state | get children_cfgs)                       
    print ""                                                     
                                                                 
}

def --env next []: nothing -> bool {
    # nu-lint-ignore: print_and_return_data
    true                                   
}

def --env submit []: nothing -> nothing {
    next                                                     
    $env.state | returns post process | util save form output
    exit # nu-lint-ignore: exit_only_in_main                 
}

def --env cancel []: nothing -> nothing {
    if not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }
    null | util save form output                                                                           
    exit # nu-lint-ignore: exit_only_in_main                                                               
}

def help []: nothing -> nothing {
    print [[group cmd desc];                                                    
        [common "status, s" "Show form status."]                                
        [null "next, n" "Fill in next unfilled field."]                         
        [null "submit, done, d" "Submit form."]                                 
        [null "cancel, c" "Abort form."]                                        
        ["req" 'req' 'Interactively set Required fields.']                      
        [null 'set req' 'Set Required fields via nushell command.']             
        [null 'get req' 'Get Required fields via nushell command.']             
        ["opt" 'opt' 'Interactively set Optional fields.']                      
        [null 'set opt' 'Set Optional fields via nushell command.']             
        [null 'get opt' 'Get Optional fields via nushell command.']             
        ["dur" 'dur' 'Interactively set Duration configuration.']               
        [null 'set dur' 'Set Duration configuration via nushell command.']      
        [null 'get dur' 'Get Duration configuration via nushell command.']      
        ["children" 'children' 'Interactively set Children configurations.']    
        [null 'set children' 'Set Children configurations via nushell command.']
        [null 'get children' 'Get Children configurations via nushell command.']
    ]                                                                           
                                                                                
}


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
	let id = {profile_id: $p.state.profile, state: $state} | api.gen API SaveTask | get id
	$env.state = $state
	$env.id = $id
}
	

alias s = status
alias n = next
alias done = submit
alias d = submit
alias c = cancel

status
help

