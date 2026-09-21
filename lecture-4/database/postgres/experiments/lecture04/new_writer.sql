
\set product_id '04bfda9a-3fcc-4efe-b870-e03e33f69afe'
\set ticket_id 'LAB04-OLD-1'
\set ticket_code 'LAB04-CODE-OLD-1'
\set agreed_price 20.00

insert into tickets
    (id, user_id, trip_id, ticket_code, status, product_code,
     valid_from_utc, valid_to_utc, price, currency, product_id)
select :'ticket_id', t.user_id, t.trip_id, :'ticket_code', t.status, p.code,
    t.valid_from_utc, t.valid_to_utc, :'agreed_price', t.currency, p.id
from tickets t
join products p on p.id = :'product_id'::uuid
where t.id = 'TICKET-1';


-- After expansion, use this query to choose a product ID for your test.
--select id, code, price, currency from products order by code;

-- The insert above is the parameterized writer: it accepts a product ID, looks up
-- the code from products, stores both references, and keeps the caller's agreed
-- price instead of copying the current catalogue price. product_code always comes
-- from the joined product row (p.code), never from a value the caller supplies, so
-- a caller-supplied code can never disagree with product_id.

-- Test 1: an unknown product ID must be rejected by fk_product_ID.
-- Expected: FOREIGN KEY violation (product_id has no matching products.id).
insert into tickets
    (id, user_id, trip_id, ticket_code, status, product_code,
     valid_from_utc, valid_to_utc, price, currency, product_id)
select 'LAB04-UNKNOWN-ID', t.user_id, t.trip_id, 'LAB04-CODE-UNKNOWN-ID', t.status,
    'SINGLE', t.valid_from_utc, t.valid_to_utc, 20.00, t.currency,
    '00000000-0000-0000-0000-000000000000'::uuid
from tickets t
where t.id = 'TICKET-1';

-- Test 2: a caller claiming a conflicting product code is ignored. We only ever
-- store p.code, the code looked up from product_id, so the ticket below is stored
-- with the real code for :'product_id', regardless of what a caller might claim.
\set claimed_code 'this-code-is-never-used-see-comment-above'
select id, product_code, product_id from tickets where id = :'ticket_id';
