-- Scheduling profile, namespace for timescales, tasks, and everything else
create table profile (
	id integer primary key autoincrement,
	name text not null,

	universe_start timestamp not null
);

-- Timescale unit
create table timescale_unit (
	size integer primary key autoincrement,
	profile integer not null references profile (id) on update cascade on delete cascade,
	name text not null
);

-- Task
create table task (
	id integer primary key autoincrement,
	profile integer not null references profile (id) on update cascade on delete cascade,

	unit integer not null references timescale_unit (size) on update cascade on delete cascade,

	name text not null,
	desc text not null
);

-- Duration type cost config (exactly 1 per task, not mut. excl with children_config)
create table dur_config (
	id integer primary key autoincrement,
	task integer not null references task (id) on update cascade on delete cascade,
	desc text not null,

	pes integer not null,
	exp integer not null,
	opt integer not null,

	deadline integer,
	total_cost integer
);

-- Children type cost config (many possible per task, not mut. excl with dur_config)
create table children_config (
	id integer primary key autoincrement,
	task integer not null references task (id) on update cascade on delete cascade,
	desc text not null,

	deadline integer,
	exp_cost integer
);

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

-- Time allocation towards a task at a particular timestamp
create table allocation (
	id integer primary key autoincrement,
	task integer not null references task (id) on update cascade on delete cascade,
	desc text not null,

	start timestamp not null,
	end timestamp not null
);

