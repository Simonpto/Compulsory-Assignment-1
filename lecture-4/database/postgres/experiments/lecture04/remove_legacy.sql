-- Start only after your ID-only reader and writer are ready.

select viewname, definition
from pg_views
where definition ilike '%product_code%';

select proname, prosrc
from pg_proc
where prosrc ilike '%product_code%';

begin;
set local lock_timeout = '3s';
alter table tickets drop column product_code;

select t.id, t.product_id, t.price, t.currency, p.code
from tickets t
         join products p on p.id = t.product_id
order by t.id;

\set product_id '04bfda9a-3fcc-4efe-b870-e03e33f69afe'
\set ticket_id 'LAB04-OLD-6'
\set agreed_price 20.00
\set ticket_code 'LAB04-CODE-OLD-8'


insert into tickets
(id, user_id, trip_id, ticket_code, status,
 valid_from_utc, valid_to_utc, price, currency, product_id)
select :'ticket_id', t.user_id, t.trip_id, :'ticket_code', t.status,
       t.valid_from_utc, t.valid_to_utc, :'agreed_price', t.currency, p.id
from tickets t
         join products p on p.id = :'product_id'::uuid
where t.id = 'TICKET-1';



-- Views/functions using tickets.product_code were inspected above (pg_views,
-- pg_proc). None reference it in this lab database, so the column is dropped
-- without CASCADE, and the final reader/writer are re-run against it below.

rollback;
-- Keep this rehearsal reversible. Record what would need to happen before
-- you committed the same change in a real rollout.
select*from tickets