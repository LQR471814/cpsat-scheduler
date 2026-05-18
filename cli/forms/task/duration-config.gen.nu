use '../../lib/util.nu'
use '../../lib/state.nu'

let p: record<prompt_prefix: string, state: record<task: oneof<int, nothing>, cfg: oneof<record<pert: record<opt: string, exp: string, pes: string>, deadline: string, total_cost: int>, nothing>, >> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(prompt prefix) ($in | do $cmd)" }

$env.state = $p.state | params post process



def --env "params post process" []: record<task: oneof<int, nothing>, cfg: oneof<record<pert: record<opt: string, exp: string, pes: string>, deadline: string, total_cost: int>, nothing>, > -> any {
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

def --env "returns post process" []: any -> record<task: oneof<int, nothing>, cfg: oneof<record<pert: record<opt: string, exp: string, pes: string>, deadline: string, total_cost: int>, nothing>, > {
    update cfg.pert.opt? { util to proto duration }  
    | update cfg.pert.exp? { util to proto duration }
    | update cfg.pert.pes? { util to proto duration }
    | update cfg.deadline? { util to proto time }    
}

def --env "prompt prefix" []: nothing -> string {
    $"($p.prompt_prefix) \(duration-config\)"
}

def --env "get pert" []: nothing -> record<opt: duration, exp: duration, pes: duration> {
    $env.state.cfg.pert
}

def --env "set pert" []: oneof<record<opt: duration, exp: duration, pes: duration>, nothing> -> nothing {
    $env.state.cfg.pert = $in
}

def --env "validate pert" []: oneof<record<opt: duration, exp: duration, pes: duration>, nothing> -> bool {
    $env.state.cfg.pert.opt != null and $env.state.cfg.pert.exp != null and $env.state.cfg.pert.pes != null
}

def --env pert [opt: duration, exp: duration, pes: duration]: nothing -> nothing {
    {opt: $opt, exp: $exp, pes: $pes} | set pert
}

def --env "unset pert" []: nothing -> nothing {
    null | set pert
}

def --env "get deadline" []: nothing -> oneof<datetime, nothing> {
    $env.state.cfg.deadline
}

def --env "set deadline" []: oneof<oneof<datetime, nothing>, nothing> -> nothing {
    
}

def --env deadline []: nothing -> nothing {
    util choose date
}

def --env "unset deadline" []: nothing -> nothing {
    null | set deadline
}

def --env "get cost" []: nothing -> int {
    $env.state.cfg.total_cost
}

def --env "set cost" []: oneof<int, nothing> -> nothing {
    
}

def --env "validate cost" []: oneof<int, nothing> -> bool {
    $env.state.cfg.total_cost != null
}

def --env cost []: nothing -> nothing {
    util input int 'Expected cost...'
}

def --env "unset cost" []: nothing -> nothing {
    null | set cost
}

def --env status []: nothing -> nothing {
    util print section title 'Form: duration-config'              
    util print label 'PERT (time estimates)'                      
    print ($env.state.cfg.pert)                                   
    print ""                                                      
    util print label 'Deadline'                                   
    print ($env.state.cfg.deadline)                               
    print ""                                                      
    util print label 'Expected cost under minimum time investment'
    print ($env.state.cfg.total_cost)                             
    print ""                                                      
                                                                  
}

def --env next []: nothing -> bool {
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
    print ([                                                                 
        'pert'                                                               
    'deadline'                                                               
    'cost'                                                                   
                                                                             
    ] | wrap fields)                                                         
}

alias s = status
alias n = next
alias done = submit
alias d = submit
alias c = cancel

status
help

