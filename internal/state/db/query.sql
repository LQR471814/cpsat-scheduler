-- name: GetProfile :one
select * from profile where id = ?;

-- name: ListProfiles :many
select * from profile;

-- name: CreateProfile :one
insert into profile (name, atomic_timescale_duration, universe_start, pert_gen_choices)
values (?, ?, ?, ?)
returning id;

-- name: DeleteProfile :exec
delete from profile where id = ?;


-- name: ListTasks :many
select * from task where profile = ?;

-- name: ListTaskEntries :many
select id, name from task
where profile = ?
order by last_modified desc;

-- name: GetTask :one
select * from task where id = ?;

-- name: CreateTask :one
insert into task (profile, unit, name, desc, start, end, last_modified)
values (?, ?, ?, ?, ?, ?, datetime('now'))
returning id;

-- name: UpdateTask :exec
update task set
	unit = ?,
	name = ?,
	desc = ?,
	start = ?,
	end = ?,
	last_modified = datetime('now')
where id = ?;

-- name: DeleteTask :exec
delete from task where id = ?;


-- name: GetDurConfig :one
select * from dur_config where task = ?;

-- name: CreateDurConfig :exec
insert into dur_config (task, pes, exp, opt, deadline, total_cost)
values (?, ?, ?, ?, ?, ?);

-- name: DeleteDurConfig :exec
delete from dur_config where task = ?;



-- name: ListPrereq :many
select p.prereq as id, t.name from prereq p
inner join task t
	on t.id = p.prereq
where postreq = ?;

-- name: ListPostreq :many
select p.postreq as id, t.name from prereq p
inner join task t
	on t.id = p.postreq
where prereq = ?;

-- name: SetPrereq :exec
insert into prereq (prereq, postreq)
values (?, ?) on conflict do nothing;


-- name: ListChildrenConfigs :many
select * from children_config where task = ?;

-- name: CreateChildrenConfig :one
insert into children_config (task, desc, deadline, exp_cost, total_cost)
values (?, ?, ?, ?, ?)
returning id;

-- name: DeleteChildrenConfigs :exec
delete from children_config where task = ?;

-- name: ListChildrenConfigChildren :many
select cc.child as id, t.name from children_config_child cc
inner join task t
	on cc.child = t.id
where cfg = ?;

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


-- name: ListScheduledTasks :many
select st.*, t.name from scheduled_task st
inner join task t on st.task = t.id
where st.start >= ? and st.end <= ? and st.profile = ?;

-- name: ListScheduledTasksInTimescale :many
select st.*, t.name from scheduled_task st
inner join task t on st.task = t.id
where st.start >= ? and st.end <= ? and st.profile = ? and t.unit = ?;

-- name: SaveScheduledTask :exec
insert into scheduled_task (task, profile, start, end, duration)
values (?, ?, ?, ?, ?) on conflict do update set
	start = excluded.start,
	end = excluded.end,
	profile = excluded.profile,
	duration = excluded.duration;

-- name: DeleteSchedule :exec
delete from scheduled_task
where profile = ?;


-- name: GetProgressLog :one
select profile from progress_log where id = ?;

-- name: ListProgressLog :many
select * from progress_log
where profile = ? and time >= sqlc.arg('start') and time < sqlc.arg('end');

-- name: CreateProgressLog :one
insert into progress_log (profile, time)
values (?, ?)
returning id;

-- name: DeleteProgressLog :exec
delete from progress_log where id = ?;

-- name: CreateUpdatedTask :exec
insert into updated_task (progress_log, id, unit, name, desc, start, end)
values (?, ?, ?, ?, ?, ?, ?);

-- name: ListUpdatedTask :many
select id, name from updated_task
where progress_log = ?;

-- name: GetLastCheckpoint :one
select time from progress_log
where profile = ?
order by time desc
limit 1;

-- name: CreateEvent :one
insert into event (profile, name, desc, start, end)
values (?, ?, ?, ?, ?)
returning id;

-- name: ReadEvent :one
select * from event where id = ?;

-- name: UpdateEvent :exec
update event set
	profile = ?,
	name = ?,
	desc = ?,
	start = ?
where id = ?;

-- name: ListEvent :many
select * from event where profile = ?;

-- name: DeleteEvent :exec
delete from event where id = ?;
