use '../../lib/util.nu'
use '../../lib/proto/apipb/api.gen.nu'
use index.nu

let p: record<prompt_prefix: string, state: nothing> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state

def "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(profiles\)"
}

def --env "read profiles" []: nothing -> table<id: int, name: string, atomic_timescale: duration, universe_start: datetime, gen_pert_choices: oneof<int, nothing>, > {
    $env.state
}

def --env "set profiles" []: oneof<table<id: int, name: string, atomic_timescale: duration, universe_start: datetime, gen_pert_choices: oneof<int, nothing>, >, nothing> -> nothing {
    $env.state = $in
}

def --env "remove profile" []: nothing -> nothing {
    let element = get profiles                                    
        | select id name                                          
        | util choose table --header 'Choose a profile to remove:'
    if $element == null {                                         
        return false                                              
    }                                                             
    {id: $element.id} | api.gen API RemoveProfile                 
    $env.state = {} | api.gen API ListProfiles | get entries      
}

def --env "add profile" [name: string, atomic_timescale: duration, universe_start: datetime, --pert_choices: int]: nothing -> nothing {
    {                                                       
        name: $name                                         
        atomic_timescale: $atomic_timescale                 
        universe_start: $universe_start                     
        gen_pert_choices: ($pert_choices | default 4)       
    } | api.gen API CreateProfile                           
    $env.state = {} | api.gen API ListProfiles | get entries
}

def --env status []: nothing -> nothing {
    util print section title 'Form: profiles'
    util print label 'Profiles'              
    print ($env.state)                       
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
        ["profiles" 'add profile' 'Add a Profiles via nushell command.']
        [null 'remove profile' 'Remove a Profiles']                     
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

$env.state = {} | api.gen API ListProfiles | get entries

