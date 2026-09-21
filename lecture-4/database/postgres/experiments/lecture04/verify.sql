-- Inspect the stored references after expansion.
begin;
\set ticket_id 'LAB04-OLD-3'
\set ticket_code 'LAB04-CODE-OLD-3'

insert into tickets
(id, user_id, trip_id, ticket_code, status, product_code,
 valid_from_utc, valid_to_utc, price, currency)
select :'ticket_id', user_id, trip_id, :'ticket_code', status, product_code,
       valid_from_utc, valid_to_utc, price, currency
from tickets
where id = 'TICKET-1';



select t.id, t.product_code, t.product_id, t.price, t.currency
from tickets t
left join products p on p.id = t.product_id
where t.product_id is null or
      p.id is null or
      p.code <> t.product_code
order by t.id;

-- The query above returns tickets with a null product_id, a missing product,
-- or a code/ID pair pointing at different products. Expect no rows after the
-- final backfill; the mismatch test happens inside this transaction and is
-- rolled back at the end so it never persists.
rollback;

