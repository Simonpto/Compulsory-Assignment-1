-- Adapted from new_writer.sql to use product_id without tickets.product_code.
-- Keeps id, user_id, trip_id, ticket_code, status, validity dates, price and
-- currency in the insert, using a fresh ticket ID and ticket code. Run this after
-- removing the old column (remove_legacy.sql); while that column still exists its
-- NOT NULL constraint would reject an insert that omits it.

\set product_id '04bfda9a-3fcc-4efe-b870-e03e33f69afe'
\set ticket_id 'LAB04-OLD-5'
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


-- After expansion, use this query to choose a product ID for your test.
--select id, code, price, currency from products order by code;

-- This is the same parameterized writer as new_writer.sql, minus product_code
-- (which no longer exists on this table): it accepts a product ID, stores it on
-- the ticket, and keeps the caller's agreed price rather than the catalogue price.

-- Test 1: an unknown product ID must still be rejected by fk_product_ID once it is
-- validated. Expected: FOREIGN KEY violation.
insert into tickets
    (id, user_id, trip_id, ticket_code, status,
     valid_from_utc, valid_to_utc, price, currency, product_id)
select 'LAB04-UNKNOWN-ID-FINAL', t.user_id, t.trip_id, 'LAB04-CODE-UNKNOWN-ID-FINAL',
    t.status, t.valid_from_utc, t.valid_to_utc, 20.00, t.currency,
    '00000000-0000-0000-0000-000000000000'::uuid
from tickets t
where t.id = 'TICKET-1';

-- Test 2: there is no product_code parameter left to conflict with product_id, so
-- the "supplied code belongs to another product" case is now structurally
-- impossible here rather than merely ignored — the column that could disagree is
-- gone.
select id, product_id, price, currency from tickets where id = :'ticket_id';
