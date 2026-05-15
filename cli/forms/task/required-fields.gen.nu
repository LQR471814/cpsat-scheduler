use '../../lib/util.nu'
use '../../lib/state.nu'

let p: record<prompt_prefix: string, state: record<id: oneof, name: oneof, desc: oneof, timescale: oneof, >> = util get form params

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

def "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(required-fields\)"
}

def "validate name" []: string -> bool {
    $env.state.name | is-not-empty
}

def name []: nothing -> nothing {
    $env.state.name = util input text Name...
}

def "set name" [value: string]: nothing -> nothing {
    $env.state.name = $value
}

def "unset name" []: nothing -> nothing {
    $env.state.name = null
}

def "get name" []: nothing -> string {
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
    util print label 'Name'          
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

status
