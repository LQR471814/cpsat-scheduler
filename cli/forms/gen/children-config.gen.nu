use '../../lib/util.nu'
use '../../lib/api.gen.nu'
use index.nu

let p: record<prompt_prefix: string, state: record<task: int, children_cfgs: table>> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state

def --env "returns post process" []: any -> table {
    get children_cfgs
}

def "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(children-config\)"
}

def --env "get config" []: nothing -> table {
    $env.state.children_cfgs
}

def --env "set config" []: oneof<table, nothing> -> nothing {
    $env.state.children_cfgs = $in
}

def --env "display config" []: table -> string {
    [                                       
        (if ($in.desc | is-not-empty) {     
            $in.desc | str substring 0..<12 
        } else { null })                    
        $'cost: ($in.exp_cost)'             
        $'children: ($in.children | length)'
    ] | str join ' '                        
}

def --env "remove config" []: nothing -> nothing {
    let element = get config                                 
    | each { display config }                                
    | enumerate                                              
    | rename id name                                         
    | util choose table --header "Choose a config to remove:"
    if $element == null {                                    
        return                                               
    }                                                        
    get config | drop nth $element.id | set config           
}

def --env config []: nothing -> nothing {
    let results = {                      
        state: {                         
            task: $p.state.task          
            desc: null                   
            deadline: null               
            exp_cost: null               
            children: []                 
        }                                
        prompt_prefix: (prompt prefix)   
    } | index form child-config          
    if $results == null { return }       
    $env.state.children_cfgs ++= $results
}

def --env "edit config" []: nothing -> nothing {
    let element = get config                               
    | each { display config }                              
    | enumerate                                            
    | rename id name                                       
    | util choose table --header "Choose a config to edit:"
    if $element == null {                                  
        return                                             
    }                                                      
    try {                                                  
        let updated = (get config | get $element.id) | do {
        let result = {                                     
        state: ($in | merge { taks: $p.state.task })       
        prompt_prefix: (prompt prefix)                     
    } | index form child-config                            
    if $result == null { error make {msg: 'form aborted'} }
    $result                                                
        }                                                  
        set (get config | update $element.id { $updated }) 
                                                           
    }                                                      
                                                           
}

def --env status []: nothing -> nothing {
    util print section title 'Form: children-config' 
    util print label 'Configs'                       
    print ($env.state.children_cfgs | display config)
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
        ["config" 'config' 'Interactively add a Configs.']      
        [null 'add config' 'Add a Configs via nushell command.']
        [null 'edit config' 'Edit a Configs']                   
    ]                                                           
                                                                
}

alias s = status
alias n = next
alias done = submit
alias d = submit
alias c = cancel

status
help

