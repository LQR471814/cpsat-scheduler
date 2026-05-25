-- Scheduling profile, namespace for timescales, tasks, and everything else
create table profile (
	id integer primary key autoincrement,
	name text not null,

	-- this is in terms of seconds
	atomic_timescale_duration int not null,
	universe_start timestamp not null,
	pert_gen_choices int
);

-- Task
create table task (
	id integer primary key autoincrement,
	profile integer not null references profile (id) on update cascade on delete cascade,

	unit integer not null,

	name text not null,
	desc text not null,
	start timestamp,
	end timestamp
);

create index idx_task_profile
on task (profile, id);

-- Duration type cost config (exactly 1 per task, not mut. excl with children_config)
create table dur_config (
	id integer primary key autoincrement,
	task integer not null references task (id) on update cascade on delete cascade,

	pes integer not null,
	exp integer not null,
	opt integer not null,

	deadline timestamp,
	total_cost integer
);

create index idx_dur_task
on dur_config (task, id);

-- Children type cost config (many possible per task, not mut. excl with dur_config)
create table children_config (
	id integer primary key autoincrement,
	task integer not null references task (id) on update cascade on delete cascade,
	desc text not null,

	deadline timestamp,
	exp_cost integer,
	total_cost integer
);

create index idx_children_task
on children_config (task, id);

-- Child part of a cost config
create table children_config_child (
	cfg integer not null references children_config (id) on update cascade on delete cascade,
	child integer not null references task (id) on update cascade on delete cascade,
	primary key (cfg, child)
);

-- Prerequisite relationship
create table prereq (
	prereq integer not null references task (id) on update cascade on delete cascade,
	postreq integer not null references task (id) on update cascade on delete cascade,
	primary key (prereq, postreq)
);

-- Child relationship
create table child (
	parent integer not null references task (id) on update cascade on delete cascade,
	child integer not null references task (id) on update cascade on delete cascade,
	primary key (parent, child)
);

-- Scheduled task
create table scheduled_task (
	task integer primary key references task (id) on update cascade on delete cascade,
	profile integer not null references profile (id),
	start timestamp not null,
	end timestamp not null
);

create index idx_scheduled_profile
on scheduled_task (profile, task);

-- Progress log
create table progress_log (
	id integer primary key autoincrement,
	profile integer not null references profile (id) on update cascade on delete cascade,
	time timestamp not null,
	desc text not null
);

create index idx_progress_log
on progress_log (profile, id);

-- Updated task
create table updated_task (
	progress_log integer not null references progress_log (id) on update cascade on delete cascade,
	task integer not null references task (id) on update cascade on delete cascade,
	desc text not null,
	primary key (progress_log, task)
);

-- Event
create table event (
	id integer primary key autoincrement,
	profile integer not null references profile (id) on update cascade on delete cascade,
	name text not null,
	desc text not null,
	start timestamp not null,
	end timestamp not null
);

