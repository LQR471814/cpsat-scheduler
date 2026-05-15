use '../../lib/util.nu'
use '../../lib/state.nu'

let p: record<prompt_prefix: string, state: record<task: oneof<int, nothing>, profile: int>> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state

def "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(task\)"
}

def task []: nothing -> nothing {
    $env.state.name = util input text Name...
}

def "set task" [value: string]: nothing -> nothing {
    $env.state.name = $value
}

def "unset task" []: nothing -> nothing {
    $env.state.name = null
}

def "get task" []: nothing -> string {
    $env.state.name
}

def "validate desc" []: string -> bool {
    $env.state.desc | is-not-empty
}

def desc []: nothing -> nothing {
    $env.state.desc = util input text Description...
}

def "set desc" [value: string]: nothing -> nothing {
    $env.state.desc = $value
}

def "unset desc" []: nothing -> nothing {
    $env.state.desc = null
}

def "get desc" []: nothing -> string {
    $env.state.desc
}

def "validate unit" []: int -> bool {
    $env.state.timescale | is-not-empty
}

def unit []: nothing -> nothing {
    $env.state.timescale = $timescales | util choose table --header 'Timescale unit:' | get id?
}

def "set unit" [value: int]: nothing -> nothing {
    $env.state.timescale = $value
}

def "unset unit" []: nothing -> nothing {
    $env.state.timescale = null
}

def "get unit" []: nothing -> int {
    $env.state.timescale
}

def status []: nothing -> nothing {
    util print label 'Task'          
    print $env.state.name            
    print ""                         
    util print label 'Desc'          
    print $env.state.desc            
    print ""                         
    util print label 'Timescale unit'
    print $env.state.timescale       
    print ""                         
                                     
}

def next []: nothing -> bool {
    # nu-lint-ignore: print_and_return_data                           
    if not ($env.state.desc | validate desc) {                        
        desc                                                          
        if not ($env.state.desc | validate desc) { return false }     
        return (next)                                                 
    }                                                                 
    if not ($env.state.timescale | validate unit) {                   
        unit                                                          
        if not ($env.state.timescale | validate unit) { return false }
        return (next)                                                 
    }                                                                 
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
	