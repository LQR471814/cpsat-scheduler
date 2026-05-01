-- name: ListProfiles :many
select * from profile;

-- name: ListTimescales :many
select name, size from timescale_unit where profile = ?
order by size asc;

-- name: CreateTask :exec
insert into task (profile, unit, name, desc) values (?, ?, ?, ?);

-- name: CreateDurConfig :exec
insert into dur_config (task, pes, exp, opt, deadline, total_cost)
values (?, ?, ?, ?, ?, ?);

-- name: CreateChildrenConfig :exec
insert into children_config (task, desc, deadline, exp_cost)
values (?, ?, ?, ?);

-- name: AddChildToConfig :exec
insert into children_config_child (cfg, child)
values (?, ?) on conflict do nothing;

-- name: SetPrereq :exec
insert into prereq (prereq, postreq)
values (?, ?) on conflict do nothing;

-- name: SetChild :exec
insert into child (parent, child)
values (?, ?) on conflict do nothing;

-- name: CreateAlloc :exec
insert into allocation (task, desc, start, end)
values (?, ?, ?, ?) on conflict do nothing;

