const SOCKET_PATH = "/tmp/cpsat-scheduler.api.sock"

const self_path = path self

export def req [api: string, method: string]: any -> any {
    let schema_path = $self_path | path dirname | path join ../../proto
	$in
        | to json --raw
        | buf curl -d @- --unix-socket $SOCKET_PATH --protocol grpc --http2-prior-knowledge --schema $schema_path $"http://localhost/($api)/($method)"
		| from json
}

def "deserialize proto dur" []: string -> duration {
	1sec * ($in | str substring 0..<(($in | str length) - 1) | into float)
}

def "deserialize proto time" []: string -> datetime {
	into datetime | date to-timezone local
}

def "serialize proto dur" []: duration -> string {
    $"($in / 1sec)s"
}

def "serialize proto time" []: datetime -> string {
    format date %+
}
export def "API ListProfiles" []: record -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>, >>> {
    serialize .ListProfilesRequest | req API ListProfiles | deserialize .ListProfilesResponse
}

export def "API CreateProfile" []: record<name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>, > -> record {
    serialize .CreateProfileRequest | req API CreateProfile | deserialize .CreateProfileResponse
}

export def "API RemoveProfile" []: record<id: oneof<nothing, int>, > -> record {
    serialize .RemoveProfileRequest | req API RemoveProfile | deserialize .RemoveProfileResponse
}

export def "API ReadTask" []: record<id: oneof<nothing, int>, > -> record<state: oneof<nothing, record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, >>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>, >>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, >>, > {
    serialize .ReadTaskRequest | req API ReadTask | deserialize .ReadTaskResponse
}

export def "API SaveTask" []: record<id: oneof<nothing, int>, profile_id: oneof<nothing, int>, state: oneof<nothing, record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, >>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>, >>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, >>, > -> record<id: oneof<nothing, int>, > {
    serialize .SaveTaskRequest | req API SaveTask | deserialize .SaveTaskResponse
}

export def "API DeleteTask" []: record<id: oneof<nothing, int>, > -> record {
    serialize .DeleteTaskRequest | req API DeleteTask | deserialize .DeleteTaskResponse
}

export def "API ListScheduledTasks" []: record<profile_id: oneof<nothing, int>, timescale: oneof<nothing, int>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, > -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    serialize .ListScheduledTasksRequest | req API ListScheduledTasks | deserialize .ListScheduledTasksResponse
}

export def "API ListPossibleRelatives" []: record<type: oneof<nothing, string>, task_id: oneof<nothing, int>, > -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    serialize .ListPossibleRelativesRequest | req API ListPossibleRelatives | deserialize .ListPossibleRelativesResponse
}

export def "API ProgressUpdate" []: record<target_task_id: oneof<nothing, int>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, > -> record {
    serialize .ProgressUpdateRequest | req API ProgressUpdate | deserialize .ProgressUpdateResponse
}

def "deserialize .DurState" []: any -> record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, >>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>, > {
    $in                                                                        
    | rename --column {pert: pert, deadline: deadline, totalCost: total_cost, }
    | update pert { deserialize .PERT }                                        
    | update deadline? { deserialize proto time }                              
    | update total_cost { into int }                                           
                                                                               
}

def "deserialize .TaskState" []: any -> record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, >>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>, >>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, > {
    $in                                                                                                                                                                                                     
    | rename --column {name: name, desc: desc, timescale: timescale, durationCfg: duration_cfg, childrenCfgs: children_cfgs, prereqs: prereqs, postreqs: postreqs, parent: parent, start: start, end: end, }
    | update timescale { into int }                                                                                                                                                                         
    | update duration_cfg? { deserialize .DurState }                                                                                                                                                        
    | update children_cfgs? { each { deserialize .ChildrenConfigState } }                                                                                                                                   
    | update prereqs? { each { deserialize .Entry } }                                                                                                                                                       
    | update postreqs? { each { deserialize .Entry } }                                                                                                                                                      
    | update parent? { deserialize .Entry }                                                                                                                                                                 
    | update start? { deserialize proto time }                                                                                                                                                              
    | update end? { deserialize proto time }                                                                                                                                                                
                                                                                                                                                                                                            
}

def "deserialize .SaveTaskResponse" []: any -> record<id: oneof<nothing, int>, > {
    $in                         
    | rename --column {id: id, }
    | update id { into int }    
                                
}

def "deserialize .ListScheduledTasksResponse" []: any -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    $in                                              
    | rename --column {entries: entries, }           
    | update entries? { each { deserialize .Entry } }
                                                     
}

def "deserialize .ProgressUpdateResponse" []: any -> record {
    $in                 
    | rename --column {}
                        
}

def "deserialize .Profile" []: any -> record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>, > {
    $in                                                                                                                                         
    | rename --column {id: id, name: name, atomicTimescale: atomic_timescale, universeStart: universe_start, genPertChoices: gen_pert_choices, }
    | update id { into int }                                                                                                                    
    | update atomic_timescale { deserialize proto dur }                                                                                         
    | update universe_start { deserialize proto time }                                                                                          
    | update gen_pert_choices? { into int }                                                                                                     
                                                                                                                                                
}

def "deserialize .ListProfilesResponse" []: any -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>, >>> {
    $in                                                
    | rename --column {entries: entries, }             
    | update entries? { each { deserialize .Profile } }
                                                       
}

def "deserialize .CreateProfileResponse" []: any -> record {
    $in                 
    | rename --column {}
                        
}

def "deserialize .PERT" []: any -> record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, > {
    $in                                               
    | rename --column {pes: pes, exp: exp, opt: opt, }
    | update pes { deserialize proto dur }            
    | update exp { deserialize proto dur }            
    | update opt { deserialize proto dur }            
                                                      
}

def "deserialize .ReadTaskResponse" []: any -> record<state: oneof<nothing, record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, >>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>, >>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, >>, > {
    $in                                      
    | rename --column {state: state, }       
    | update state { deserialize .TaskState }
                                             
}

def "deserialize .RemoveProfileResponse" []: any -> record {
    $in                 
    | rename --column {}
                        
}

def "deserialize .Entry" []: any -> record<id: oneof<nothing, int>, name: oneof<nothing, string>, > {
    $in                                     
    | rename --column {id: id, name: name, }
    | update id { into int }                
                                            
}

def "deserialize .ChildrenConfigState" []: any -> record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    $in                                                                                        
    | rename --column {desc: desc, deadline: deadline, expCost: exp_cost, children: children, }
    | update deadline? { deserialize proto time }                                              
    | update exp_cost { into int }                                                             
    | update children? { each { deserialize .Entry } }                                         
                                                                                               
}

def "deserialize .DeleteTaskResponse" []: any -> record {
    $in                 
    | rename --column {}
                        
}

def "deserialize .ListPossibleRelativesResponse" []: any -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    $in                                              
    | rename --column {entries: entries, }           
    | update entries? { each { deserialize .Entry } }
                                                     
}

def "serialize .PERT" []: record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, > -> any {
    $in                                 
    | update pes { serialize proto dur }
    | update exp { serialize proto dur }
    | update opt { serialize proto dur }
                                        
}

def "serialize .DurState" []: record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, >>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>, > -> any {
    $in                                        
    | update pert { serialize .PERT }          
    | update deadline? { serialize proto time }
                                               
}

def "serialize .ChildrenConfigState" []: record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> -> any {
    $in                                             
    | update deadline? { serialize proto time }     
    | update children? { each { serialize .Entry } }
                                                    
}

def "serialize .SaveTaskRequest" []: record<id: oneof<nothing, int>, profile_id: oneof<nothing, int>, state: oneof<nothing, record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, >>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>, >>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, >>, > -> any {
    $in                                    
    | update state { serialize .TaskState }
                                           
}

def "serialize .ListScheduledTasksRequest" []: record<profile_id: oneof<nothing, int>, timescale: oneof<nothing, int>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, > -> any {
    $in                                    
    | update start { serialize proto time }
    | update end { serialize proto time }  
                                           
}

def "serialize .ListPossibleRelativesRequest" []: record<type: oneof<nothing, string>, task_id: oneof<nothing, int>, > -> any {
    $in
       
}

def "serialize .ProgressUpdateRequest" []: record<target_task_id: oneof<nothing, int>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, > -> any {
    $in                                    
    | update start { serialize proto time }
    | update end { serialize proto time }  
                                           
}

def "serialize .ListProfilesRequest" []: record -> any {
    $in
       
}

def "serialize .CreateProfileRequest" []: record<name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>, > -> any {
    $in                                              
    | update atomic_timescale { serialize proto dur }
    | update universe_start { serialize proto time } 
                                                     
}

def "serialize .ReadTaskRequest" []: record<id: oneof<nothing, int>, > -> any {
    $in
       
}

def "serialize .Entry" []: record<id: oneof<nothing, int>, name: oneof<nothing, string>, > -> any {
    $in
       
}

def "serialize .TaskState" []: record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, >>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>, >>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, > -> any {
    $in                                                                
    | update duration_cfg? { serialize .DurState }                     
    | update children_cfgs? { each { serialize .ChildrenConfigState } }
    | update prereqs? { each { serialize .Entry } }                    
    | update postreqs? { each { serialize .Entry } }                   
    | update parent? { serialize .Entry }                              
    | update start? { serialize proto time }                           
    | update end? { serialize proto time }                             
                                                                       
}

def "serialize .DeleteTaskRequest" []: record<id: oneof<nothing, int>, > -> any {
    $in
       
}

def "serialize .RemoveProfileRequest" []: record<id: oneof<nothing, int>, > -> any {
    $in
       
}

