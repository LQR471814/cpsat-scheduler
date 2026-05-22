use '../../lib/util.nu'
use '../../lib/api.gen.nu'
use index.nu

let p: record<prompt_prefix: string, state: record<task: int, desc: oneof<string, nothing>, deadline: oneof<datetime, nothing>, exp_cost: oneof<int, nothing>, children: table<id: int, name: string>>> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state

def --env "returns post process" []: any -> record<task: int, desc: oneof<string, nothing>, deadline: oneof<datetime, nothing>, exp_cost: oneof<int, nothing>, children: table<id: int, name: string>> {
    reject task
}

def "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(child-config\)"
}

def --env "get desc" []: nothing -> string {
    $env.state.desc
}

def --env "set desc" []: oneof<string, nothing> -> nothing {
    $env.state.desc = $in
}

def --env desc []: nothing -> nothing {
    $env.state.desc = util input multiline Description...
}

def --env "unset desc" []: nothing -> nothing {
    null | set desc
}

def --env "get exp_cost" []: nothing -> int {
    $env.state.exp_cost
}

def --env "set exp_cost" []: oneof<int, nothing> -> nothing {
    $env.state.exp_cost = $in
}

def --env "validate exp_cost" []: oneof<int, nothing> -> bool {
    $env.state.exp_cost != null
}

def --env exp_cost []: nothing -> nothing {
    $env.state.exp_cost = util input int 'Cost... (integer)'
}

def --env "unset exp_cost" []: nothing -> nothing {
    null | set exp_cost
}

def --env "get deadline" []: nothing -> datetime {
    $env.state.deadline
}

def --env "set deadline" []: oneof<datetime, nothing> -> nothing {
    $env.state.deadline = $in
}

def --env "validate deadline" []: oneof<datetime, nothing> -> bool {
    $env.state.deadline != null
}

def --env deadline []: nothing -> nothing {
    $env.state.deadline = util choose date
}

def --env "unset deadline" []: nothing -> nothing {
    null | set deadline
}

def --env "get children" []: nothing -> table<id: int, name: string> {
    $env.state.children
}

def --env "set children" []: oneof<table<id: int, name: string>, nothing> -> nothing {
    $env.state.children = $in
}

def --env "validate children" []: oneof<table<id: int, name: string>, nothing> -> bool {
    $env.state.children | is-not-empty
}

def --env "remove children" []: nothing -> nothing {
    let element = get children                                 
    | each { to json -r }                                      
    | enumerate                                                
    | rename id name                                           
    | util choose table --header "Choose a children to remove:"
    if $element == null {                                      
        return                                                 
    }                                                          
    get children | drop nth $element.id | set children         
}

def --env children []: nothing -> nothing {
    let child = {                                                                                          
        type: CHILD                                                                                        
        task_id: $p.state.task                                                                             
    } | api.gen API ListPossibleRelatives | get entries | util choose table --header 'Choose child to add:'
    if $child == null { return }                                                                           
    $env.state.children ++= $child                                                                         
}

def --env status []: nothing -> nothing {
    util print section title 'Form: child-config'
    util print label 'Description'               
    print ($env.state.desc)                      
    print ""                                     
    util print label 'Expected cost'             
    print ($env.state.exp_cost)                  
    print ""                                     
    util print label 'Deadline'                  
    util print date ($env.state.deadline)        
    print ""                                     
    util print label 'Children'                  
    print ($env.state.children)                  
    print ""                                     
                                                 
}

alias s = status
def --env next []: nothing -> bool {
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
        children                                                         
        if not ($env.state.children | validate children) { return false }
        return (next)                                                    
    }                                                                    
    true                                                                 
}

alias n = next
def help []: nothing -> nothing {
    print [[group cmd desc];                                          
        [common "status, s" "Show form status."]                      
        [null "next, n" "Fill in next unfilled field."]               
        [null "submit, done, d" "Submit form."]                       
        [null "cancel, c" "Abort form."]                              
        ["desc" 'desc' 'Interactively set Description.']              
        [null 'set desc' 'Set Description via nushell command.']      
        [null 'get desc' 'Get Description via nushell command.']      
        ["exp_cost" 'exp_cost' 'Interactively set Expected cost.']    
        [null 'set exp_cost' 'Set Expected cost via nushell command.']
        [null 'get exp_cost' 'Get Expected cost via nushell command.']
        ["deadline" 'deadline' 'Interactively set Deadline.']         
        [null 'set deadline' 'Set Deadline via nushell command.']     
        [null 'get deadline' 'Get Deadline via nushell command.']     
        ["children" 'children' 'Interactively add a Children.']       
        [null 'add children' 'Add a Children via nushell command.']   
    ]                                                                 
                                                                      
}

alias h = help
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

alias done = submit
alias d = submit
alias c = cancel

status
help