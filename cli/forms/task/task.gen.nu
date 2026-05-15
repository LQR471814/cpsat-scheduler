use '../../lib/util.nu'
use '../../lib/state.nu'

let p: record<prompt_prefix: string, state: record<task: oneof<int, nothing>, profile: int>> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state

def "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(task\)"
}

def "get req" []: nothing -> record<name: string, desc: string, timescale: int> {
    $env.state | select name desc timescale
}

def "set req" []: oneof<record<name: string, desc: string, timescale: int>, nothing> -> nothing {
    let value = $in                                                      
    $env.state = $env.state | merge ($value | select name desc timescale)
}

def req []: nothing -> nothing {
    util exec form ./required-fields.gen.nu (get req)
}

def "unset req" []: nothing -> nothing {
    null | set req
}

def "get opt" []: nothing -> record<parent: oneof<record<id: int, name: string>, nothing>, start: oneof<record<seconds: int, nanos: int>, nothing>, end: oneof<record<seconds: int, nanos: int>, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>> {
    $env.state | select parent start end prereqs postreqs
}

def "set opt" []: oneof<record<parent: oneof<record<id: int, name: string>, nothing>, start: oneof<record<seconds: int, nanos: int>, nothing>, end: oneof<record<seconds: int, nanos: int>, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>>, nothing> -> nothing {
    let value = $in                                                                    
    $env.state = $env.state | merge ($value | select parent start end prereqs postreqs)
}

def opt []: nothing -> nothing {
    util exec form ./optional-fields.gen.nu (get opt | merge { id: $env.id })
}

def "unset opt" []: nothing -> nothing {
    null | set opt
}

def "get dur" []: nothing -> oneof<record<pert: record<opt: record<seconds: int, nanos: int>, exp: record<seconds: int, nanos: int>, pes: record<seconds: int, nanos: int>>, deadline: record<seconds: int, nanos: int>, total_cost: int>, nothing> {
    $env.state | get dur_cfg
}

def "set dur" []: oneof<oneof<record<pert: record<opt: record<seconds: int, nanos: int>, exp: record<seconds: int, nanos: int>, pes: record<seconds: int, nanos: int>>, deadline: record<seconds: int, nanos: int>, total_cost: int>, nothing>, nothing> -> nothing {
    $env.state.dur_cfg = $in
}

def dur []: nothing -> nothing {
    util exec form ./duration-config.gen.nu ({ task: $env.id, cfg: (get dur) })
}

def "unset dur" []: nothing -> nothing {
    null | set dur
}

def "get children" []: nothing -> table {
    $env.state | get children_cfgs
}

def "set children" []: oneof<table, nothing> -> nothing {
    $env.state.children_cfgs = $in
}

def children []: nothing -> nothing {
    util exec form ./children-config-list.gen.nu ({ task: $env.id, children_cfgs: (get children) })
}

def "unset children" []: nothing -> nothing {
    null | set children
}

def status []: nothing -> nothing {
    util print label 'Required'                                  
    print ($env.state | select name desc timescale)              
    print ""                                                     
    util print label 'Optional'                                  
    print ($env.state | select parent start end prereqs postreqs)
    print ""                                                     
    util print label 'Duration configuration'                    
    print ($env.state | get dur_cfg)                             
    print ""                                                     
    util print label 'Children configurations'                   
    print ($env.state | get children_cfgs)                       
    print ""                                                     
                                                                 
}

def next []: nothing -> bool {
    # nu-lint-ignore: print_and_return_data
    true                                   
}

def submit []: nothing -> nothing {
    next                                    
    $env.state | util save form output      
    exit # nu-lint-ignore: exit_only_in_main
}

def cancel []: nothing -> nothing {
    null | util save form output            
    exit # nu-lint-ignore: exit_only_in_main
}

def help []: nothing -> table<group: oneof<string, nothing>, cmd: string, desc: string> {
    [[group cmd desc];                                                       
        [common "status, s"       "Show form status."]                       
        [null   "next, n"         "Fill in next unfilled field."]            
        [null   "submit, done, d" "Submit form."]                            
        [null   "cancel, c"       "Abort form."]                             
        [fields "<field>"         "Set field value with interactive picker."]
        [null   "set <field>"     "Set field value."]                        
        [null   "get <field>"     "Get field value."]                        
        [null   "unset <field>"   "Unset field value."]                      
        [lists  "add <field>"     "Add to list."]                            
        [null   "list <field>"    "List elements."]                          
        [null   "remove <field>"  "Remove from list interactively."]         
    ]                                                                        
}

alias s = status
alias n = next
alias done = submit
alias d = submit
alias c = cancel


if $p.task != null {
	$env.state = state read task $p.task | get state
	$env.id = $p.id
} else {
	let results = util exec form ./required-fields.gen.nu {
		prompt_prefix: (prompt prefix)
		name: null
		desc: null
		timescale: null
	}
	if $results == null {
		cancel
	}
	let state = {
		parent: null
        start: null
        end: null
        prereqs: []
        postreqs: []

		duration_cfg: {
            opt: 2
            exp: 4
            pes: 6
            total_cost: 0
        }
        children_cfgs: []
	} | merge $results
	let id = state save task $p.profile $state | get id
	$env.state = $state
	$env.id = $id
}
	