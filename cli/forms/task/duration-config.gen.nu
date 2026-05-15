use '../../lib/util.nu'
use '../../lib/state.nu'

let p: record<prompt_prefix: string, state: record<task: oneof<int, nothing>, cfg: oneof<record<pert: record<opt: record<seconds: int, nanos: int>, exp: record<seconds: int, nanos: int>, pes: record<seconds: int, nanos: int>>, deadline: record<seconds: int, nanos: int>, total_cost: int>, nothing>, >> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state | params post process



def "params post process" []: record<task: oneof<int, nothing>, cfg: oneof<record<pert: record<opt: record<seconds: int, nanos: int>, exp: record<seconds: int, nanos: int>, pes: record<seconds: int, nanos: int>>, deadline: record<seconds: int, nanos: int>, total_cost: int>, nothing>, > -> any {
    update cfg { default {                             
            pert: {                                    
                opt: null                              
                exp: null                              
                pes: null                              
            }                                          
            deadline: null                             
        } }                                            
    | update cfg.pert.opt? { util from proto duration }
    | update cfg.pert.exp? { util from proto duration }
    | update cfg.pert.pes? { util from proto duration }
    | update cfg.deadline? { util from proto time }    
}

def "returns post process" []: any -> record<task: oneof<int, nothing>, cfg: oneof<record<pert: record<opt: record<seconds: int, nanos: int>, exp: record<seconds: int, nanos: int>, pes: record<seconds: int, nanos: int>>, deadline: record<seconds: int, nanos: int>, total_cost: int>, nothing>, > {
    update cfg.pert.opt? { util to proto duration }  
    | update cfg.pert.exp? { util to proto duration }
    | update cfg.pert.pes? { util to proto duration }
    | update cfg.deadline? { util to proto time }    
}

def "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(duration-config\)"
}

def "validate pert" []: list<int> -> bool {
    $env.state.cfg.pert.opt != null and $env.state.cfg.pert.exp != null and $env.state.cfg.pert.pes != null
}

def "set pert" [opt: int, exp: int, pes: int]: nothing -> nothing {
    $env.state.cfg.pert = {opt: $opt, exp: $exp, pes: $pes}
}

def "unset pert" []: nothing -> nothing {
    $env.state.cfg.pert = null
}

def "get pert" []: nothing -> list<int> {
    $env.state.cfg.pert
}

def deadline []: nothing -> nothing {
    util choose date
}

def "set deadline" [value: oneof<datetime, nothing>]: nothing -> nothing {
    $env.state.cfg.deadline = $value
}

def "unset deadline" []: nothing -> nothing {
    $env.state.cfg.deadline = null
}

def "get deadline" []: nothing -> oneof<datetime, nothing> {
    $env.state.cfg.deadline
}

def "validate cost" []: int -> bool {
    $env.state.cfg.total_cost != null
}

def cost []: nothing -> nothing {
    util input int
}

def "set cost" [value: int]: nothing -> nothing {
    $env.state.cfg.total_cost = $value
}

def "unset cost" []: nothing -> nothing {
    $env.state.cfg.total_cost = null
}

def "get cost" []: nothing -> int {
    $env.state.cfg.total_cost
}

def status []: nothing -> nothing {
    util print label 'PERT (time estimates)'                      
    print $env.state.cfg.pert                                     
    print ""                                                      
    util print label 'Deadline'                                   
    print $env.state.cfg.deadline                                 
    print ""                                                      
    util print label 'Expected cost under minimum time investment'
    print $env.state.cfg.total_cost                               
    print ""                                                      
                                                                  
}

def next []: nothing -> bool {
    # nu-lint-ignore: print_and_return_data                                
    if not ($env.state.cfg.pert | validate pert) {                         
        print "set pert with 'set pert'"                                   
        return false                                                       
    }                                                                      
    if not ($env.state.cfg.total_cost | validate cost) {                   
        cost                                                               
        if not ($env.state.cfg.total_cost | validate cost) { return false }
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