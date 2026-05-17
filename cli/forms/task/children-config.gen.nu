use '../../lib/util.nu'
use '../../lib/state.nu'

let p: record<prompt_prefix: string, state: record<task: int, children_cfgs: table>> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state

def --env "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(children-configs\)"
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

def --env "add config" []: nothing -> nothing {
    let results = util exec form ./children-config.gen.nu {
        task: $p.task                                      
        state: null                                        
        prompt_prefix: (prompt prefix)                     
    }                                                      
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
        let result = util exec form ./children-config.gen.nu {
        task: $p.task                                         
        state: $in                                            
        prompt_prefix: (prompt prefix)                        
    }                                                         
    if $result == null { error make {msg: 'form aborted'} }   
    $result                                                   
        }                                                     
        set (config | update $element.id { $updated })        
    }                                                         
                                                              
}

def --env status []: nothing -> nothing {
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
    $env.state | util save form output      
    exit # nu-lint-ignore: exit_only_in_main
}

def --env cancel []: nothing -> nothing {
    null | util save form output            
    exit # nu-lint-ignore: exit_only_in_main
}

def --env help []: nothing -> table<group: oneof<string, nothing>, cmd: string, desc: string> {
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