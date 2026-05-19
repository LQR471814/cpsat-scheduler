use '../../lib/util.nu'
use '../../lib/state.nu'
use index.nu

let p: record<prompt_prefix: string, state: record<id: oneof<int, nothing>, parent: oneof<record<id: int, name: string>, nothing>, start: oneof<string, nothing>, end: oneof<string, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>>> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state | params post process



def --env "params post process" []: record<id: oneof<int, nothing>, parent: oneof<record<id: int, name: string>, nothing>, start: oneof<string, nothing>, end: oneof<string, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>> -> any {
    update start? { util from proto time }    
        | update end? { util from proto time }
}

def --env "returns post process" []: any -> record<id: oneof<int, nothing>, parent: oneof<record<id: int, name: string>, nothing>, start: oneof<string, nothing>, end: oneof<string, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>> {
    update start { util to proto time }    
        | update end { util to proto time }
}

def --env "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(optional-fields\)"
}

def --env "get parent" []: nothing -> record<id: int, name: string> {
    $env.state.parent
}

def --env "set parent" []: oneof<record<id: int, name: string>, nothing> -> nothing {
    $env.state.parent = $in
}

def --env parent []: nothing -> nothing {
    $env.state.parent = state list possible relatives PARENT $p.state.id | util choose table --header 'Choose parent'
}

def --env "unset parent" []: nothing -> nothing {
    null | set parent
}

def --env "get start" []: nothing -> datetime {
    $env.state.start
}

def --env "set start" []: oneof<datetime, nothing> -> nothing {
    $env.state.start = $in
}

def --env "validate start" []: oneof<datetime, nothing> -> bool {
    if $env.state.start != null and $env.state.end != null {
        $env.state.start < $env.state.end                   
    } else { true }                                         
}

def --env start []: nothing -> nothing {
    $env.state.start = util choose date
}

def --env "unset start" []: nothing -> nothing {
    null | set start
}

def --env "get end" []: nothing -> datetime {
    $env.state.end
}

def --env "set end" []: oneof<datetime, nothing> -> nothing {
    $env.state.end = $in
}

def --env "validate end" []: oneof<datetime, nothing> -> bool {
    if $env.state.start != null and $env.state.end != null {
        $env.state.start < $env.state.end                   
    } else { true }                                         
}

def --env end []: nothing -> nothing {
    $env.state.end = util choose date
}

def --env "unset end" []: nothing -> nothing {
    null | set end
}

def --env "get prereqs" []: nothing -> table<id: int, name: string> {
    $env.state.prereqs
}

def --env "set prereqs" []: oneof<table<id: int, name: string>, nothing> -> nothing {
    $env.state.prereqs = $in
}

def --env "display prereqs" []: table<id: int, name: string> -> string {
    $in.name
}

def --env "remove prereqs" []: nothing -> nothing {
    let element = get prereqs                                 
    | each { display prereqs }                                
    | enumerate                                               
    | rename id name                                          
    | util choose table --header "Choose a prereqs to remove:"
    if $element == null {                                     
        return                                                
    }                                                         
    get prereqs | drop nth $element.id | set prereqs          
}

def --env prereqs []: nothing -> nothing {
    let chosen = state list possible relatives PREREQ $p.state.id | util choose table --header 'Add a task as a prerequisite:'
    if $chosen == null { return }                                                                                             
    $env.state.prereqs ++= $chosen                                                                                            
}

def --env "get postreqs" []: nothing -> table<id: int, name: string> {
    $env.state.postreqs
}

def --env "set postreqs" []: oneof<table<id: int, name: string>, nothing> -> nothing {
    $env.state.postreqs = $in
}

def --env "display postreqs" []: table<id: int, name: string> -> string {
    $in.name
}

def --env "remove postreqs" []: nothing -> nothing {
    let element = get postreqs                                 
    | each { display postreqs }                                
    | enumerate                                                
    | rename id name                                           
    | util choose table --header "Choose a postreqs to remove:"
    if $element == null {                                      
        return                                                 
    }                                                          
    get postreqs | drop nth $element.id | set postreqs         
}

def --env postreqs []: nothing -> nothing {
    let chosen = state list possible relatives POSTREQ $p.state.id | util choose table --header 'Add a task as a postrequisite:'
    if $chosen == null { return }                                                                                               
    $env.state.postreqs ++= $chosen                                                                                             
}

def --env status []: nothing -> nothing {
    util print section title 'Form: optional-fields'
    util print label 'Parent'                       
    print ($env.state.parent)                       
    print ""                                        
    util print label 'Must start after'             
    util print date ($env.state.start)              
    print ""                                        
    util print label 'Must end before'              
    util print date ($env.state.end)                
    print ""                                        
    util print label 'Prerequisites'                
    print ($env.state.prereqs | display prereqs)    
    print ""                                        
    util print label 'Postrequisites'               
    print ($env.state.postreqs | display postreqs)  
    print ""                                        
                                                    
}

def --env next []: nothing -> bool {
    # nu-lint-ignore: print_and_return_data                        
    if not ($env.state.start | validate start) {                   
        start                                                      
        if not ($env.state.start | validate start) { return false }
        return (next)                                              
    }                                                              
    if not ($env.state.end | validate end) {                       
        end                                                        
        if not ($env.state.end | validate end) { return false }    
        return (next)                                              
    }                                                              
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

def --env help []: nothing -> nothing {
    print [[group cmd desc];                                             
        [common "status, s" "Show form status."]                         
        [null "next, n" "Fill in next unfilled field."]                  
        [null "submit, done, d" "Submit form."]                          
        [null "cancel, c" "Abort form."]                                 
        ["parent" 'parent' 'Interactively set Parent.']                  
        [null 'set parent' 'Set Parent via nushell command.']            
        [null 'get parent' 'Get Parent via nushell command.']            
        ["start" 'start' 'Interactively set Must start after.']          
        [null 'set start' 'Set Must start after via nushell command.']   
        [null 'get start' 'Get Must start after via nushell command.']   
        ["end" 'end' 'Interactively set Must end before.']               
        [null 'set end' 'Set Must end before via nushell command.']      
        [null 'get end' 'Get Must end before via nushell command.']      
        ["prereqs" 'prereqs' 'Interactively add a Prerequisites.']       
        [null 'add prereqs' 'Add a Prerequisites via nushell command.']  
        ["postreqs" 'postreqs' 'Interactively add a Postrequisites.']    
        [null 'add postreqs' 'Add a Postrequisites via nushell command.']
    ]                                                                    
                                                                         
}

alias s = status
alias n = next
alias done = submit
alias d = submit
alias c = cancel

status
help

