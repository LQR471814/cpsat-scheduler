-- +goose Up
-- +goose StatementBegin

update dur_config
set total_cost = 0
where total_cost is null;

create table dur_config_new (
	id integer primary key autoincrement,
	task integer not null references task (id) on update cascade on delete cascade,

	pes integer not null,
	exp integer not null,
	opt integer not null,

	deadline timestamp,
	total_cost integer not null
);

insert into dur_config_new (id, task, pes, exp, opt, deadline, total_cost)
select * from dur_config;

drop table dur_config;

alter table dur_config_new rename to dur_config;

-- +goose StatementEnd
