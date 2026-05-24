const SOCKET_PATH = "/tmp/cpsat-scheduler.api.sock"

const self_path = path self

export def req [api: string, method: string]: any -> any {
    let schema_path = $self_path | path dirname | path join ../../proto
	let res = $in
        | to json --raw
        | buf curl -d @- --unix-socket $SOCKET_PATH --protocol grpc --http2-prior-knowledge --schema $schema_path $"http://localhost/($api)/($method)"
		| complete
	if $res.exit_code == 0 {
		$res.stdout | from json
	} else {
		error make {msg: 'gRPC returned error'}
	}
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

export def "API ListPossibleRelatives" []: record<type: oneof<nothing, string>, task_id: oneof<nothing, int>, > -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    serialize .ListPossibleRelativesRequest | req API ListPossibleRelatives | deserialize .ListPossibleRelativesResponse
}

export def "API RecomputeSchedule" []: record<profile: oneof<nothing, int>, > -> record {
    serialize .RecomputeScheduleRequest | req API RecomputeSchedule | deserialize .RecomputeScheduleResponse
}

export def "API ListScheduledTasks" []: record<profile_id: oneof<nothing, int>, timescale: oneof<nothing, int>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, > -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    serialize .ListScheduledTasksRequest | req API ListScheduledTasks | deserialize .ListScheduledTasksResponse
}

export def "API ListProgressUpdates" []: record<profile: oneof<nothing, int>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, > -> record<logs: list<record<id: oneof<nothing, int>, time: oneof<nothing, datetime>, desc: oneof<nothing, string>, updates: list<record<task: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, desc: oneof<nothing, string>, >>>>> {
    serialize .ListProgressUpdatesRequest | req API ListProgressUpdates | deserialize .ListProgressUpdatesResponse
}

export def "API ProgressUpdate" []: record<profile: oneof<nothing, int>, time: oneof<nothing, datetime>, desc: oneof<nothing, string>, updates: list<record<task: oneof<nothing, int>, desc: oneof<nothing, string>, >>> -> record<id: oneof<nothing, int>, > {
    serialize .ProgressUpdateRequest | req API ProgressUpdate | deserialize .ProgressUpdateResponse
}

export def "API EditProgressLog" []: record<id: oneof<nothing, int>, time: oneof<nothing, datetime>, desc: oneof<nothing, string>, updates: list<record<task: oneof<nothing, int>, desc: oneof<nothing, string>, >>> -> record {
    serialize .EditProgressLogRequest | req API EditProgressLog | deserialize .EditProgressLogResponse
}

export def "API DeleteProgressLog" []: record<id: oneof<nothing, int>, > -> record {
    serialize .DeleteProgressLogRequest | req API DeleteProgressLog | deserialize .DeleteProgressLogResponse
}

export def "API GetLastCheckpoint" []: record<profile: oneof<nothing, int>, > -> record<time: oneof<nothing, datetime>, > {
    serialize .GetLastCheckpointRequest | req API GetLastCheckpoint | deserialize .GetLastCheckpointResponse
}

export def "API CreateEvent" []: record<event: list<record<profile: oneof<nothing, int>, name: oneof<nothing, string>, desc: oneof<nothing, string>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, >>> -> record {
    serialize .CreateEventRequest | req API CreateEvent | deserialize .CreateEventResponse
}

export def "API ReadEvent" []: record<id: oneof<nothing, int>, > -> record<event: oneof<nothing, record<profile: oneof<nothing, int>, name: oneof<nothing, string>, desc: oneof<nothing, string>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, >>, > {
    serialize .ReadEventRequest | req API ReadEvent | deserialize .ReadEventResponse
}

export def "API UpdateEvent" []: record<id: oneof<nothing, int>, event: oneof<nothing, record<profile: oneof<nothing, int>, name: oneof<nothing, string>, desc: oneof<nothing, string>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, >>, > -> record {
    serialize .UpdateEventRequest | req API UpdateEvent | deserialize .UpdateEventResponse
}

export def "API ListEvent" []: record<profile: oneof<nothing, int>, > -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    serialize .ListEventRequest | req API ListEvent | deserialize .ListEventResponse
}

export def "API RemoveEvent" []: record<id: oneof<nothing, int>, > -> record {
    serialize .RemoveEventRequest | req API RemoveEvent | deserialize .RemoveEventResponse
}

def "deserialize .UpdateEventResponse" []: any -> record {
    $in
       
}

def "deserialize .RemoveEventResponse" []: any -> record {
    $in
       
}

def "deserialize .ListProfilesResponse" []: any -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>, >>> {
    $in                                                
    | update entries? { each { deserialize .Profile } }
    | default [] entries                               
                                                       
}

def "deserialize .PERT" []: any -> record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, > {
    $in                                   
    | update pes { deserialize proto dur }
    | update exp { deserialize proto dur }
    | update opt { deserialize proto dur }
                                          
}

def "deserialize .Entry" []: any -> record<id: oneof<nothing, int>, name: oneof<nothing, string>, > {
    $in                     
    | update id { into int }
                            
}

def "deserialize .ChildrenConfigState" []: any -> record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    $in                                                              
    | if $in.expCost? != null { rename --column {expCost: exp_cost} }
    | update deadline? { deserialize proto time }                    
    | update exp_cost { into int }                                   
    | update children? { each { deserialize .Entry } }               
    | default [] children                                            
                                                                     
}

def "deserialize .ListScheduledTasksResponse" []: any -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    $in                                              
    | update entries? { each { deserialize .Entry } }
    | default [] entries                             
                                                     
}

def "deserialize .ListProgressUpdatesResponse.ProgressLog" []: any -> record<id: oneof<nothing, int>, time: oneof<nothing, datetime>, desc: oneof<nothing, string>, updates: list<record<task: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, desc: oneof<nothing, string>, >>> {
    $in                                                                                            
    | update id { into int }                                                                       
    | update time { deserialize proto time }                                                       
    | update updates? { each { deserialize .ListProgressUpdatesResponse.ProgressLog.UpdatedTask } }
    | default [] updates                                                                           
                                                                                                   
}

def "deserialize .EditProgressLogResponse" []: any -> record {
    $in
       
}

def "deserialize .DeleteProgressLogResponse" []: any -> record {
    $in
       
}

def "deserialize .CreateProfileResponse" []: any -> record {
    $in
       
}

def "deserialize .RemoveProfileResponse" []: any -> record {
    $in
       
}

def "deserialize .TaskState" []: any -> record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, >>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>, >>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, > {
    $in                                                                          
    | if $in.durationCfg? != null { rename --column {durationCfg: duration_cfg} }
    | rename --column {childrenCfgs: children_cfgs}                              
    | update timescale { into int }                                              
    | update duration_cfg? { deserialize .DurState }                             
    | update children_cfgs? { each { deserialize .ChildrenConfigState } }        
    | update prereqs? { each { deserialize .Entry } }                            
    | update postreqs? { each { deserialize .Entry } }                           
    | update parent? { deserialize .Entry }                                      
    | update start? { deserialize proto time }                                   
    | update end? { deserialize proto time }                                     
    | default [] children_cfgs                                                   
    | default [] prereqs                                                         
    | default [] postreqs                                                        
                                                                                 
}

def "deserialize .ListPossibleRelativesResponse" []: any -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    $in                                              
    | update entries? { each { deserialize .Entry } }
    | default [] entries                             
                                                     
}

def "deserialize .ReadEventResponse" []: any -> record<event: oneof<nothing, record<profile: oneof<nothing, int>, name: oneof<nothing, string>, desc: oneof<nothing, string>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, >>, > {
    $in                                  
    | update event { deserialize .Event }
                                         
}

def "deserialize .ListEventResponse" []: any -> record<entries: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> {
    $in                                              
    | update entries? { each { deserialize .Entry } }
    | default [] entries                             
                                                     
}

def "deserialize .Profile" []: any -> record<id: oneof<nothing, int>, name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>, > {
    $in                                                                                      
    | if $in.atomicTimescale? != null { rename --column {atomicTimescale: atomic_timescale} }
    | if $in.universeStart? != null { rename --column {universeStart: universe_start} }      
    | if $in.genPertChoices? != null { rename --column {genPertChoices: gen_pert_choices} }  
    | update id { into int }                                                                 
    | update atomic_timescale { deserialize proto dur }                                      
    | update universe_start { deserialize proto time }                                       
    | update gen_pert_choices? { into int }                                                  
                                                                                             
}

def "deserialize .ReadTaskResponse" []: any -> record<state: oneof<nothing, record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, >>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>, >>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, >>, > {
    $in                                      
    | update state { deserialize .TaskState }
                                             
}

def "deserialize .SaveTaskResponse" []: any -> record<id: oneof<nothing, int>, > {
    $in                     
    | update id { into int }
                            
}

def "deserialize .DeleteTaskResponse" []: any -> record {
    $in
       
}

def "deserialize .RecomputeScheduleResponse" []: any -> record {
    $in
       
}

def "deserialize .ListProgressUpdatesResponse.ProgressLog.UpdatedTask" []: any -> record<task: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, desc: oneof<nothing, string>, > {
    $in                                 
    | update task { deserialize .Entry }
                                        
}

def "deserialize .ProgressUpdateResponse" []: any -> record<id: oneof<nothing, int>, > {
    $in                     
    | update id { into int }
                            
}

def "deserialize .GetLastCheckpointResponse" []: any -> record<time: oneof<nothing, datetime>, > {
    $in                                      
    | update time? { deserialize proto time }
                                             
}

def "deserialize .DurState" []: any -> record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, >>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>, > {
    $in                                                                    
    | if $in.totalCost? != null { rename --column {totalCost: total_cost} }
    | update pert { deserialize .PERT }                                    
    | update deadline? { deserialize proto time }                          
    | update total_cost { into int }                                       
                                                                           
}

def "deserialize .ListProgressUpdatesResponse" []: any -> record<logs: list<record<id: oneof<nothing, int>, time: oneof<nothing, datetime>, desc: oneof<nothing, string>, updates: list<record<task: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, desc: oneof<nothing, string>, >>>>> {
    $in                                                                             
    | update logs? { each { deserialize .ListProgressUpdatesResponse.ProgressLog } }
    | default [] logs                                                               
                                                                                    
}

def "deserialize .CreateEventResponse" []: any -> record {
    $in
       
}

def "deserialize .Event" []: any -> record<profile: oneof<nothing, int>, name: oneof<nothing, string>, desc: oneof<nothing, string>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, > {
    $in                                      
    | update profile { into int }            
    | update start { deserialize proto time }
    | update end { deserialize proto time }  
                                             
}

def "serialize .ProgressUpdateRequest" []: record<profile: oneof<nothing, int>, time: oneof<nothing, datetime>, desc: oneof<nothing, string>, updates: list<record<task: oneof<nothing, int>, desc: oneof<nothing, string>, >>> -> any {
    $in                                                                        
    | update time { serialize proto time }                                     
    | update updates? { each { serialize .ProgressUpdateRequest.UpdatedTask } }
                                                                               
}

def "serialize .EditProgressLogRequest.UpdatedTask" []: record<task: oneof<nothing, int>, desc: oneof<nothing, string>, > -> any {
    $in
       
}

def "serialize .EditProgressLogRequest" []: record<id: oneof<nothing, int>, time: oneof<nothing, datetime>, desc: oneof<nothing, string>, updates: list<record<task: oneof<nothing, int>, desc: oneof<nothing, string>, >>> -> any {
    $in                                                                         
    | update time { serialize proto time }                                      
    | update updates? { each { serialize .EditProgressLogRequest.UpdatedTask } }
                                                                                
}

def "serialize .ReadEventRequest" []: record<id: oneof<nothing, int>, > -> any {
    $in
       
}

def "serialize .UpdateEventRequest" []: record<id: oneof<nothing, int>, event: oneof<nothing, record<profile: oneof<nothing, int>, name: oneof<nothing, string>, desc: oneof<nothing, string>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, >>, > -> any {
    $in                                
    | update event { serialize .Event }
                                       
}

def "serialize .ListEventRequest" []: record<profile: oneof<nothing, int>, > -> any {
    $in
       
}

def "serialize .RemoveEventRequest" []: record<id: oneof<nothing, int>, > -> any {
    $in
       
}

def "serialize .ListProfilesRequest" []: record -> any {
    $in
       
}

def "serialize .ChildrenConfigState" []: record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>> -> any {
    $in                                             
    | update deadline? { serialize proto time }     
    | update children? { each { serialize .Entry } }
                                                    
}

def "serialize .DeleteTaskRequest" []: record<id: oneof<nothing, int>, > -> any {
    $in
       
}

def "serialize .ListPossibleRelativesRequest" []: record<type: oneof<nothing, string>, task_id: oneof<nothing, int>, > -> any {
    $in
       
}

def "serialize .ListProgressUpdatesRequest" []: record<profile: oneof<nothing, int>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, > -> any {
    $in                                    
    | update start { serialize proto time }
    | update end { serialize proto time }  
                                           
}

def "serialize .Event" []: record<profile: oneof<nothing, int>, name: oneof<nothing, string>, desc: oneof<nothing, string>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, > -> any {
    $in                                    
    | update start { serialize proto time }
    | update end { serialize proto time }  
                                           
}

def "serialize .ReadTaskRequest" []: record<id: oneof<nothing, int>, > -> any {
    $in
       
}

def "serialize .RecomputeScheduleRequest" []: record<profile: oneof<nothing, int>, > -> any {
    $in
       
}

def "serialize .ListScheduledTasksRequest" []: record<profile_id: oneof<nothing, int>, timescale: oneof<nothing, int>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, > -> any {
    $in                                    
    | update start { serialize proto time }
    | update end { serialize proto time }  
                                           
}

def "serialize .DeleteProgressLogRequest" []: record<id: oneof<nothing, int>, > -> any {
    $in
       
}

def "serialize .CreateEventRequest" []: record<event: list<record<profile: oneof<nothing, int>, name: oneof<nothing, string>, desc: oneof<nothing, string>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, >>> -> any {
    $in                                          
    | update event? { each { serialize .Event } }
                                                 
}

def "serialize .CreateProfileRequest" []: record<name: oneof<nothing, string>, atomic_timescale: oneof<nothing, duration>, universe_start: oneof<nothing, datetime>, gen_pert_choices: oneof<nothing, int>, > -> any {
    $in                                              
    | update atomic_timescale { serialize proto dur }
    | update universe_start { serialize proto time } 
                                                     
}

def "serialize .RemoveProfileRequest" []: record<id: oneof<nothing, int>, > -> any {
    $in
       
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

def "serialize .SaveTaskRequest" []: record<id: oneof<nothing, int>, profile_id: oneof<nothing, int>, state: oneof<nothing, record<name: oneof<nothing, string>, desc: oneof<nothing, string>, timescale: oneof<nothing, int>, duration_cfg: oneof<nothing, record<pert: oneof<nothing, record<pes: oneof<nothing, duration>, exp: oneof<nothing, duration>, opt: oneof<nothing, duration>, >>, deadline: oneof<nothing, datetime>, total_cost: oneof<nothing, int>, >>, children_cfgs: list<record<desc: oneof<nothing, string>, deadline: oneof<nothing, datetime>, exp_cost: oneof<nothing, int>, children: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>>>, prereqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, postreqs: list<record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, parent: oneof<nothing, record<id: oneof<nothing, int>, name: oneof<nothing, string>, >>, start: oneof<nothing, datetime>, end: oneof<nothing, datetime>, >>, > -> any {
    $in                                    
    | update state { serialize .TaskState }
                                           
}

def "serialize .ProgressUpdateRequest.UpdatedTask" []: record<task: oneof<nothing, int>, desc: oneof<nothing, string>, > -> any {
    $in
       
}

def "serialize .GetLastCheckpointRequest" []: record<profile: oneof<nothing, int>, > -> any {
    $in
       
}

def "serialize .Entry" []: record<id: oneof<nothing, int>, name: oneof<nothing, string>, > -> any {
    $in
       
}

