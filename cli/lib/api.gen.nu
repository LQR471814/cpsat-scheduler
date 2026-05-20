const SOCKET_PATH = "/tmp/cpsat-scheduler.api.sock"

const self_path = path self

export def req [api: string, method: string]: any -> any {
    let schema_path = $self_path | path dirname | path join ../../proto
	$in
        | to json --raw
        | buf curl -d @- --unix-socket $SOCKET_PATH --protocol grpc --http2-prior-knowledge --schema $schema_path $"http://localhost/($api)/($method)"
		| from json
}

def "proto deserialize dur" []: string -> duration {
	1sec * (str substring 0..<(($in | str length) - 1) | into float)
}

def "proto deserialize time" []: string -> datetime {
	into datetime | date to-timezone local
}

def "proto serialize dur" []: duration -> string {
    $"($in / 1sec)s"
}

def "proto serialize time" []: datetime -> string {
    format date %+
}
export def "API ListProfiles" []: record -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, >>> {
    serialize .ListProfilesRequest | req API ListProfiles | deserialize .ListProfilesResponse
}

export def "API CreateProfile" []: record<name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>, > -> record {
    serialize .CreateProfileRequest | req API CreateProfile | deserialize .CreateProfileResponse
}

export def "API RemoveProfile" []: record<id: oneof<nothing, int>, > -> record {
    serialize .RemoveProfileRequest | req API RemoveProfile | deserialize .RemoveProfileResponse
}

export def "API ReadTask" []: record<id: oneof<nothing, int>, > -> record<state: oneof<nothing, record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, children_cfgs: list<record<desc: oneof<nothing, string>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, > {
    serialize .ReadTaskRequest | req API ReadTask | deserialize .ReadTaskResponse
}

export def "API SaveTask" []: record<profile_id: oneof<nothing, int>, state: oneof<nothing, record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, children_cfgs: list<record<desc: oneof<nothing, string>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, > -> record<id: oneof<nothing, int>, > {
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

def "deserialize .ChildrenConfigState" []: any -> record<desc: oneof<nothing, string>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    $in                                          
    | update desc { $in }                        
    | update deadline? { proto deserialize time }
    | update exp_cost { into int }               
    | update children { deserialize .Entry }     
                                                 
}

def "deserialize .Profile" []: any -> record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, > {
    $in                                                
    | update id { into int }                           
    | update name { $in }                              
    | update atomic_timescale { proto deserialize dur }
    | update universe_start { proto deserialize time } 
    | update gen_pert_choices? { into int }            
                                                       
}

def "deserialize .DurState" []: any -> record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, >>, total_cost: oneof<nothing, int>, > {
    $in                                          
    | update pert { deserialize .PERT }          
    | update deadline? { proto deserialize time }
    | update total_cost { into int }             
                                                 
}

def "deserialize .ListPossibleRelativesResponse" []: any -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    $in                                    
    | update entries { deserialize .Entry }
                                           
}

def "deserialize .ProgressUpdateResponse" []: any -> record {
    $in
       
}

def "deserialize .ListProfilesResponse" []: any -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, >>> {
    $in                                      
    | update entries { deserialize .Profile }
                                             
}

def "deserialize .TaskState" []: any -> record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, children_cfgs: list<record<desc: oneof<nothing, string>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    $in                                                        
    | update name { $in }                                      
    | update desc { $in }                                      
    | update timescale { into int }                            
    | update duration_cfg? { deserialize .DurState }           
    | update children_cfgs { deserialize .ChildrenConfigState }
    | update prereqs { deserialize .Entry }                    
    | update postreqs { deserialize .Entry }                   
    | update parent? { deserialize .Entry }                    
    | update start? { proto deserialize time }                 
    | update end? { proto deserialize time }                   
                                                               
}

def "deserialize .ReadTaskResponse" []: any -> record<state: oneof<nothing, record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, children_cfgs: list<record<desc: oneof<nothing, string>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, > {
    $in                                      
    | update state { deserialize .TaskState }
                                             
}

def "deserialize .CreateProfileResponse" []: any -> record {
    $in
       
}

def "deserialize .RemoveProfileResponse" []: any -> record {
    $in
       
}

def "deserialize .PERT" []: any -> record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, > {
    $in                                   
    | update pes { proto deserialize dur }
    | update exp { proto deserialize dur }
    | update opt { proto deserialize dur }
                                          
}

def "deserialize .Entry" []: any -> record<id: oneof<nothing, int>, name: oneof<nothing, string>, > {
    $in                     
    | update id { into int }
    | update name { $in }   
                            
}

def "deserialize .SaveTaskResponse" []: any -> record<id: oneof<nothing, int>, > {
    $in                     
    | update id { into int }
                            
}

def "deserialize .DeleteTaskResponse" []: any -> record {
    $in
       
}

def "deserialize .ListScheduledTasksResponse" []: any -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    $in                                    
    | update entries { deserialize .Entry }
                                           
}

def "serialize .ListPossibleRelativesRequest" []: record<type: oneof<nothing, string>, task_id: oneof<nothing, int>, > -> any {
    $in                     
    | update type { $in }   
    | update task_id { $in }
                            
}

def "serialize .ProgressUpdateRequest" []: record<target_task_id: oneof<nothing, int>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, > -> any {
    $in                                    
    | update target_task_id { $in }        
    | update start { proto serialize time }
    | update end { proto serialize time }  
                                           
}

def "serialize .CreateProfileRequest" []: record<name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>, > -> any {
    $in                                              
    | update name { $in }                            
    | update atomic_timescale { proto serialize dur }
    | update universe_start { proto serialize time } 
    | update gen_pert_choices { $in }                
                                                     
}

def "serialize .ReadTaskRequest" []: record<id: oneof<nothing, int>, > -> any {
    $in                
    | update id { $in }
                       
}

def "serialize .DeleteTaskRequest" []: record<id: oneof<nothing, int>, > -> any {
    $in                
    | update id { $in }
                       
}

def "serialize .ListProfilesRequest" []: record -> any {
    $in
       
}

def "serialize .RemoveProfileRequest" []: record<id: oneof<nothing, int>, > -> any {
    $in                
    | update id { $in }
                       
}

def "serialize .SaveTaskRequest" []: record<profile_id: oneof<nothing, int>, state: oneof<nothing, record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, children_cfgs: list<record<desc: oneof<nothing, string>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, > -> any {
    $in                                      
    | update id? { $in }                     
    | update profile_id { $in }              
    | update state { deserialize .TaskState }
                                             
}

def "serialize .ListScheduledTasksRequest" []: record<profile_id: oneof<nothing, int>, timescale: oneof<nothing, int>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, > -> any {
    $in                                    
    | update profile_id { $in }            
    | update timescale { $in }             
    | update start { proto serialize time }
    | update end { proto serialize time }  
                                           
}

