use '../lib/util.nu'
use '../lib/state.nu'

let p: record<prompt_prefix: string, state: nothing> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state

def "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(profiles\)"
}

def "get profiles" []: nothing -> table<id: int, name: string, atomic_timescale: record<seconds: int, nanos: int>, universe_start: record<seconds: int, nanos: int>, gen_pert_choices: oneof<int, nothing>, > {
    $env.state | default []
}

def "set profiles" []: oneof<table<id: int, name: string, atomic_timescale: record<seconds: int, nanos: int>, universe_start: record<seconds: int, nanos: int>, gen_pert_choices: oneof<int, nothing>, >, nothing> -> nothing {
    $env.state = $in
}

def "remove profiles" []: nothing -> nothing {
    let element = get profiles                                 
    | each { to json -r }                                      
    | enumerate                                                
    | rename id name                                           
    | util choose table --header "Choose a profiles to remove:"
    if $element == null {                                      
        return false                                           
    }                                                          
    get profiles | drop nth $element.id | set profiles         
}

def status []: nothing -> nothing {
    util print label 'Profiles'    
    print ($env.state | default [])
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

$env.state = state list profiles