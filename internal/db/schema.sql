create table task (
	-- this is a UUIDv4
	id blob primary key,
	parent_id blob references task (id),

	-- metadata
	name text not null,
	comments text not null,

	-- these are in minutes
	margin_optimistic integer not null,
	margin_expected integer not null,
	margin_pessimistic integer not null
);

