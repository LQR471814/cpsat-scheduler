-- name: ListProfiles :many
select * from profile;


-- name: ListTimescales :many
select name, size from timescale_unit where profile = ?
order by size asc;


-- name: ListTasks :many
select * from task where profile = ?;

-- name: GetTask :one
select * from task where id = ?;

-- name: CreateTask :one
insert into task (profile, unit, name, desc, start, end) values (?, ?, ?, ?, ?, ?)
returning id;

-- name: UpdateTask :exec
update task set
	unit = ?,
	name = ?,
	desc = ?,
	start = ?,
	end = ?
where id = ?;


-- name: GetDurConfig :one
select * from dur_config where task = ?;

-- name: CreateDurConfig :exec
insert into dur_config (task, pes, exp, opt, deadline, total_cost)
values (?, ?, ?, ?, ?, ?);

-- name: DeleteDurConfig :exec
delete from dur_config where task = ?;



-- name: ListPrereq :many
select prereq from prereq where postreq = ?;

-- name: ListPostreq :many
select postreq from prereq where prereq = ?;

-- name: SetPrereq :exec
insert into prereq (prereq, postreq)
values (?, ?) on conflict do nothing;


-- name: ListChildrenConfigs :many
select * from children_config where task = ?;

-- name: CreateChildrenConfig :exec
insert into children_config (task, desc, deadline, exp_cost, total_cost)
values (?, ?, ?, ?, ?);

-- name: DeleteChildrenConfigs :exec
delete from children_config where task = ?;

-- name: ListChildrenConfigChildren :many
select child from children_config_child where cfg = ?;

-- name: AddChildToConfig :exec
insert into children_config_child (cfg, child)
values (?, ?) on conflict do nothing;

-- name: GetParent :one
select t.* from task as t
inner join children_config as c on
	t.id = c.task
inner join children_config_child cc on
	c.id = cc.cfg
where cc.child = ?
group by t.id;

-- name: SetChild :exec
insert into child (parent, child)
values (?, ?) on conflict do nothing;


-- name: CreateAlloc :exec
insert into allocation (task, desc, start, end)
values (?, ?, ?, ?) on conflict do nothing;

