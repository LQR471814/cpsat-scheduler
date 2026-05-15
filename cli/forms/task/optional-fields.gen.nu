use '../../lib/util.nu'
use '../../lib/state.nu'

let p: record<prompt_prefix: string, state: record<id: oneof<int, nothing>, parent: oneof<record<id: int, name: string>, nothing>, start: oneof<record<seconds: int, nanos: int>, nothing>, end: oneof<record<seconds: int, nanos: int>, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>>> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state | params post process



def "params post process" []: record<id: oneof<int, nothing>, parent: oneof<record<id: int, name: string>, nothing>, start: oneof<record<seconds: int, nanos: int>, nothing>, end: oneof<record<seconds: int, nanos: int>, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>> -> any {
    update start { util from proto time }    
        | update end { util from proto time }
}

def "returns post process" []: any -> record<id: oneof<int, nothing>, parent: oneof<record<id: int, name: string>, nothing>, start: oneof<record<seconds: int, nanos: int>, nothing>, end: oneof<record<seconds: int, nanos: int>, nothing>, prereqs: table<id: int, name: string>, postreqs: table<id: int, name: string>> {
    update start { util to proto time }    
        | update end { util to proto time }
}

def "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(optional-fields\)"
}

def "get parent" []: nothing -> record<id: int, name: string> {
    $env.state.parent
}

def "set parent" []: oneof<record<id: int, name: string>, nothing> -> nothing {
    $env.state.parent = $in
}

def parent []: nothing -> nothing {
    $env.state.parent = state list possible relatives PARENT $p.id | util choose table --header 'Choose parent'
}

def "unset parent" []: nothing -> nothing {
    null | set parent
}

def "get start" []: nothing -> record<seconds: int, nanos: int> {
    $env.state.start
}

def "set start" []: oneof<record<seconds: int, nanos: int>, nothing> -> nothing {
    $env.state.start = $in
}

def "validate start" []: record<seconds: int, nanos: int> -> bool {
    if $env.state.start != null and $env.state.end != null {
        $env.state.start < $env.state.end                   
    } else { true }                                         
}

def start []: nothing -> nothing {
    $env.state.start = util choose date
}

def "unset start" []: nothing -> nothing {
    null | set start
}

def "get end" []: nothing -> record<seconds: int, nanos: int> {
    $env.state.end
}

def "set end" []: oneof<record<seconds: int, nanos: int>, nothing> -> nothing {
    $env.state.end = $in
}

def "validate end" []: record<seconds: int, nanos: int> -> bool {
    if $env.state.start != null and $env.state.end != null {
        $env.state.start < $env.state.end                   
    } else { true }                                         
}

def end []: nothing -> nothing {
    $env.state.end = util choose date
}

def "unset end" []: nothing -> nothing {
    null | set end
}

def "get prereqs" []: nothing -> table<id: int, name: string> {
    $env.state.prereqs
}

def "set prereqs" []: oneof<table<id: int, name: string>, nothing> -> nothing {
    $env.state.prereqs = $in
}

def "display prereqs" []: table<id: int, name: string> -> string {
    $in.name
}

def "remove prereqs" []: nothing -> nothing {
    let element = get prereqs                                 
    | each { display prereqs }                                
    | enumerate                                               
    | rename id name                                          
    | util choose table --header "Choose a prereqs to remove:"
    if $element == null {                                     
        return false                                          
    }                                                         
    set prereqs (get prereqs | drop nth $element.id)          
}

def "add prereqs" []: nothing -> nothing {
    let chosen = state list possible relatives PREREQ $p.id | util choose table --header 'Add a task as a prerequisite:'
    if $chosen == null { return }                                                                                       
    $env.state.prereqs ++= $chosen                                                                                      
}

def "get postreqs" []: nothing -> table<id: int, name: string> {
    $env.state.postreqs
}

def "set postreqs" []: oneof<table<id: int, name: string>, nothing> -> nothing {
    $env.state.postreqs = $in
}

def "display postreqs" []: table<id: int, name: string> -> string {
    $in.name
}

def "remove postreqs" []: nothing -> nothing {
    let element = get postreqs                                 
    | each { display postreqs }                                
    | enumerate                                                
    | rename id name                                           
    | util choose table --header "Choose a postreqs to remove:"
    if $element == null {                                      
        return false                                           
    }                                                          
    set postreqs (get postreqs | drop nth $element.id)         
}

def "add postreqs" []: nothing -> nothing {
    let chosen = state list possible relatives POSTREQ $p.id | util choose table --header 'Add a task as a postrequisite:'
    if $chosen == null { return }                                                                                         
    $env.state.postreqs ++= $chosen                                                                                       
}

def status []: nothing -> nothing {
    util print label 'Parent'                     
    print ($env.state.parent)                     
    print ""                                      
    util print label 'Must start after'           
    print ($env.state.start)                      
    print ""                                      
    util print label 'Must end before'            
    print ($env.state.end)                        
    print ""                                      
    util print label 'Prerequisites'              
    print ($env.state.prereqs | display prereqs)  
    print ""                                      
    util print label 'Postrequisites'             
    print ($env.state.postreqs | display postreqs)
    print ""                                      
                                                  
}

def next []: nothing -> bool {
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