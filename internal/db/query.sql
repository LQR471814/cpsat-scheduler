-- name: ListProfiles :many
select * from profile;

-- name: ListTimescales :many
select name, size from timescale_unit where profile = ?
order by size asc;

