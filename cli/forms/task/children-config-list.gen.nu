use '../../lib/util.nu'
use '../../lib/state.nu'

let p: record<prompt_prefix: string, state: record<task: int, desc: oneof<string, nothing>, deadline: oneof<string, nothing>, exp_cost: oneof<int, nothing>, children: table<id: int, name: string>>> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state

def "returns post process" []: any -> record<task: int, desc: oneof<string, nothing>, deadline: oneof<string, nothing>, exp_cost: oneof<int, nothing>, children: table<id: int, name: string>> {
    reject task
}

def "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(children-config-list\)"
}

def "get desc" []: nothing -> string {
    $env.state.desc
}

def "set desc" []: oneof<string, nothing> -> nothing {
    $env.state.desc = $in
}

def desc []: nothing -> nothing {
    $env.state.desc = util input multiline Description...
}

def "unset desc" []: nothing -> nothing {
    null | set desc
}

def "get exp_cost" []: nothing -> int {
    $env.state.exp_cost
}

def "set exp_cost" []: oneof<int, nothing> -> nothing {
    $env.state.exp_cost = $in
}

def "validate exp_cost" []: int -> bool {
    $env.state.exp_cost != null
}

def exp_cost []: nothing -> nothing {
    $env.state.exp_cost = util input int 'Cost... (integer)'
}

def "unset exp_cost" []: nothing -> nothing {
    null | set exp_cost
}

def "get deadline" []: nothing -> string {
    $env.state.deadline
}

def "set deadline" []: oneof<string, nothing> -> nothing {
    $env.state.deadline = $in
}

def "validate deadline" []: string -> bool {
    $env.state.deadline != null
}

def deadline []: nothing -> nothing {
    $env.state.deadline = util choose date
}

def "unset deadline" []: nothing -> nothing {
    null | set deadline
}

def "get children" []: nothing -> table<id: int, name: string> {
    $env.state.children
}

def "set children" []: oneof<table<id: int, name: string>, nothing> -> nothing {
    $env.state.children = $in
}

def "validate children" []: table<id: int, name: string> -> bool {
    $env.state.children | is-not-empty
}

def "remove children" []: nothing -> nothing {
    let element = get children                                 
    | each { to json -r }                                      
    | enumerate                                                
    | rename id name                                           
    | util choose table --header "Choose a children to remove:"
    if $element == null {                                      
        return false                                           
    }                                                          
    get children | drop nth $element.id | set children         
}

def "add children" []: nothing -> nothing {
    let child = state list possible relatives CHILD $p.task | util choose table --header 'Choose child to add:'
    if $child == null { return }                                                                               
    $env.state.children ++= $child                                                                             
}

def status []: nothing -> nothing {
    util print label 'Description'  
    print ($env.state.desc)         
    print ""                        
    util print label 'Expected cost'
    print ($env.state.exp_cost)     
    print ""                        
    util print label 'Deadline'     
    print ($env.state.deadline)     
    print ""                        
    util print label 'Children'     
    print ($env.state.children)     
    print ""                        
                                    
}

def next []: nothing -> bool {
    # nu-lint-ignore: print_and_return_data                              
    if not ($env.state.exp_cost | validate exp_cost) {                   
        exp_cost                                                         
        if not ($env.state.exp_cost | validate exp_cost) { return false }
        return (next)                                                    
    }                                                                    
    if not ($env.state.deadline | validate deadline) {                   
        deadline                                                         
        if not ($env.state.deadline | validate deadline) { return false }
        return (next)                                                    
    }                                                                    
    if not ($env.state.children | validate children) {                   
        add children                                                     
        if not ($env.state.children | validate children) { return false }
        return (next)                                                    
    }                                                                    
    true                                                                 
}

def submit []: nothing -> nothing {
    next                                                     
    $env.state | returns post process | util save form output
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