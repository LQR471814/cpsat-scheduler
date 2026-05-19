use '../../lib/util.nu'
use '../../lib/state.nu'
use index.nu

let p: record<prompt_prefix: string, state: record<name: oneof<string, nothing>, desc: oneof<string, nothing>, timescale: oneof<int, nothing>, >> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state

let timescales: table<id: int, name: string> = [[id, name];
    [96, "day"]
    [672, "week"]
    [2688, "month"]
    [8064, "quarter"]
    [32256, "year"]
    [64512, "2 year"]
    [129024, "4 year"]
    [258048, "8 year"]
    [516096, "16 year"]
    [1032192, "32 year"]
    [2064384, "64 year"]
    [4128768, "128 year"]
]

def --env "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(required-fields\)"
}

def --env "get name" []: nothing -> string {
    $env.state.name
}

def --env "set name" []: oneof<string, nothing> -> nothing {
    $env.state.name = $in
}

def --env "validate name" []: oneof<string, nothing> -> bool {
    $env.state.name | is-not-empty
}

def --env name []: nothing -> nothing {
    $env.state.name = util input text Name...
}

def --env "unset name" []: nothing -> nothing {
    null | set name
}

def --env "get desc" []: nothing -> string {
    $env.state.desc
}

def --env "set desc" []: oneof<string, nothing> -> nothing {
    $env.state.desc = $in
}

def --env "validate desc" []: oneof<string, nothing> -> bool {
    $env.state.desc != null
}

def --env desc []: nothing -> nothing {
    $env.state.desc = util input text Description...
}

def --env "unset desc" []: nothing -> nothing {
    null | set desc
}

def --env "get unit" []: nothing -> int {
    $env.state.timescale
}

def --env "set unit" []: oneof<int, nothing> -> nothing {
    $env.state.timescale = $in
}

def --env "validate unit" []: oneof<int, nothing> -> bool {
    $env.state.timescale | is-not-empty
}

def --env unit []: nothing -> nothing {
    $env.state.timescale = $timescales | util choose table --header 'Timescale unit (bounds maximum duration):' | get id?
}

def --env "unset unit" []: nothing -> nothing {
    null | set unit
}

def --env status []: nothing -> nothing {
    util print section title 'Form: required-fields'           
    util print label 'Name'                                    
    print ($env.state.name)                                    
    print ""                                                   
    util print label 'Desc'                                    
    print ($env.state.desc)                                    
    print ""                                                   
    util print label 'Timescale unit (bounds maximum duration)'
    print ($env.state.timescale)                               
    print ""                                                   
                                                               
}

def --env next []: nothing -> bool {
    # nu-lint-ignore: print_and_return_data                           
    if not ($env.state.name | validate name) {                        
        name                                                          
        if not ($env.state.name | validate name) { return false }     
        return (next)                                                 
    }                                                                 
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

def --env submit []: nothing -> nothing {
    next                                    
    $env.state | util save form output      
    exit # nu-lint-ignore: exit_only_in_main
}

def --env cancel []: nothing -> nothing {
    if not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }
    null | util save form output                                                                           
    exit # nu-lint-ignore: exit_only_in_main                                                               
}

def --env help []: nothing -> nothing {
    print [[group cmd desc];                                                                 
        [common "status, s" "Show form status."]                                             
        [null "next, n" "Fill in next unfilled field."]                                      
        [null "submit, done, d" "Submit form."]                                              
        [null "cancel, c" "Abort form."]                                                     
        ["name" 'name' 'Interactively set Name.']                                            
        [null 'set name' 'Set Name via nushell command.']                                    
        [null 'get name' 'Get Name via nushell command.']                                    
        ["desc" 'desc' 'Interactively set Desc.']                                            
        [null 'set desc' 'Set Desc via nushell command.']                                    
        [null 'get desc' 'Get Desc via nushell command.']                                    
        ["unit" 'unit' 'Interactively set Timescale unit (bounds maximum duration).']        
        [null 'set unit' 'Set Timescale unit (bounds maximum duration) via nushell command.']
        [null 'get unit' 'Get Timescale unit (bounds maximum duration) via nushell command.']
    ]                                                                                        
                                                                                             
}

alias s = status
alias n = next
alias done = submit
alias d = submit
alias c = cancel

status
help

