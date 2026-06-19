let db = open ./state.db

let roots: table = $db
  # select all tasks which are not children of some config
  | query db "select t.* from task t
left join children_config_child c
  on c.child = t.id
where c.cfg is null"

def "query task" []: int -> oneof<record, nothing> {
  let id = $in
  $db
  | query db $"select unit, name, start, end from task
where id = ($id)"
  | first
}

def "query dur cfg" []: int -> oneof<record, nothing> {
  let id = $in
  $db
  | query db $"select * from dur_config
where task = ($id)"
  | first
}

def "query child configs" []: int -> table {
  let id = $in
  $db
  | query db $"select * from children_config
where task = ($id)"
}

def "query child config children" []: int -> list<int> {
  let id = $in
  $db
  | query db $"select child from children_config_child
where cfg = ($id)"
  | get child
}

def "construct tree" []: int -> record {
  let id = $in
  let task = $id | query task
  let dur_cfg = $id | query dur cfg
  let child_configs = $id
    | query child configs
    | each {|cfg|
      $cfg | merge {
        children: (
          $cfg.id
          | query child config children
          | each { construct tree }
        )
      }
    }
    | reject id task
  {id: $id}
  | merge $task
  | merge {
    dur: $dur_cfg
    children: $child_configs
  }
  | if $in.dur == null { reject dur } else { $in }
  | if $in.children == null { reject children } else { $in }
}

$roots
| get id
| each { construct tree }
| to yaml
