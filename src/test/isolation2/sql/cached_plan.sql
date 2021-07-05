-- Commit 99fbc8ea9 introduces a invalid pointer reference
-- bug and we do not have test case cover that code path.
-- This case is to make sure unlock logic of cached plan works
-- well.

create extension if not exists gp_inject_fault;

create table sales_row_99fbc8 (id int, date date, amt decimal(10,2))
distributed by (id)
partition by range (date)
( start (date '2008-01-01') inclusive
end (date '2009-01-01') exclusive
every (interval '1 month') );

-- a plan without any params will always be cached and used
1: prepare cached_plan_99fbc8 as insert into sales_row_99fbc8 values (1, '2008-01-01'::date);

select gp_inject_fault('wait_for_cached_plan_invalid', 'suspend', dbid) from gp_segment_configuration where role = 'p' and content = -1;

1&: execute cached_plan_99fbc8;

select gp_wait_until_triggered_fault('wait_for_cached_plan_invalid', 1, dbid) from gp_segment_configuration where role = 'p' and content = -1;

-- in a new session, drop the table, and this should
-- invalidate the cached plan that already locked previously.
2: vacuum full sales_row_99fbc8;

-- let the session 1 continue, make sure it does not coredump
select gp_inject_fault('wait_for_cached_plan_invalid', 'reset', dbid) from gp_segment_configuration where role = 'p' and content = -1;

1<:
1q:
2q:

drop table sales_row_99fbc8;
