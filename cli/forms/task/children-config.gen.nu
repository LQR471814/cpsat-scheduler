use '../../lib/util.nu'
use '../../lib/state.nu'

let p: record<prompt_prefix: string, state: record<task: int, children_cfgs: table>> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state

def --env "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(children-configs\)"
}

def --env "get configs" []: nothing -> table {
    $env.state.children_cfgs
}

def --env "set configs" []: oneof<table, nothing> -> nothing {
    $env.state.children_cfgs = $in
}

def --env "display configs" []: table -> string {
    [                                       
        (if ($in.desc | is-not-empty) {     
            $in.desc | str substring 0..<12 
        } else { null })                    
        $'cost: ($in.exp_cost)'             
        $'children: ($in.children | length)'
    ] | str join ' '                        
}

def --env "remove configs" []: nothing -> nothing {
    let element = get configs                                 
    | each { display configs }                                
    | enumerate                                               
    | rename id name                                          
    | util choose table --header "Choose a configs to remove:"
    if $element == null {                                     
        return false                                          
    }                                                         
    get configs | drop nth $element.id | set configs          
}

def --env "add configs" []: nothing -> nothing {
    let results = util exec form ./children-config.gen.nu {
        task: $p.task                                      
        state: null                                        
        prompt_prefix: (prompt prefix)                     
    }                                                      
    if $results == null { return }                         
    $env.state.children_cfgs ++= $results                  
}

def --env status []: nothing -> nothing {
    util print label 'Configs'                        
    print ($env.state.children_cfgs | display configs)
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