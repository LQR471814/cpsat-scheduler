use '../lib/util.nu'
use '../lib/state.nu'

let p: record<prompt_prefix: string, state: nothing> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state

def --env "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(profiles\)"
}

def --env "get profiles" []: nothing -> table<id: int, name: string, atomic_timescale: string, universe_start: string, gen_pert_choices: oneof<int, nothing>, > {
    $env.state
}

def --env "set profiles" []: oneof<table<id: int, name: string, atomic_timescale: string, universe_start: string, gen_pert_choices: oneof<int, nothing>, >, nothing> -> nothing {
    $env.state = $in
}

def --env "remove profile" []: nothing -> nothing {
    let element = get profiles                                    
        | select id name                                          
        | util choose table --header 'Choose a profile to remove:'
    if $element == null {                                         
        return false                                              
    }                                                             
    state remove profile $element.id                              
    $env.state = state list profiles                              
}

def --env "add profile" [name: string, atomic_timescale: duration, universe_start: datetime, --pert_choices: int]: nothing -> nothing {
    state create profile $name ($atomic_timescale | util to proto dur) ($universe_start | util to proto time) ($pert_choices | default 4) | complete
    $env.state = state list profiles                                                                                                                
}

def --env status []: nothing -> nothing {
    util print section title 'Form: profiles'
    util print label 'Profiles'              
    print ($env.state)                       
    print ""                                 
                                             
}

def --env next []: nothing -> bool {
    # nu-lint-ignore: print_and_return_data
    true                                   
}

def --env submit []: nothing -> nothing {
    next                                    
    $env.state | util save form output      
    exit # nu-lint-ignore: exit_only_in_main
}

def --env cancel []: nothing -> nothing {
    null | util save form output            
    exit # nu-lint-ignore: exit_only_in_main
}

def --env help []: nothing -> nothing {
    print [[group cmd desc];                                                 
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
    print ([                                                                 
        'profiles'                                                           
                                                                             
    ] | wrap fields)                                                         
}

$env.state = state list profilesalias s = status
alias n = next
alias done = submit
alias d = submit
alias c = cancel

status
help

