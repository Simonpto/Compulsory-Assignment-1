-- Copy to 031_backfill_ticket_product.sql and complete it.
-- Resolve only tickets whose product_id is null.
-- Match the existing product code and preserve assigned IDs and historical prices.
-- The second run must change zero rows.

-- Repeatable: the WHERE clause only ever touches rows where product_id is
-- still null, so running this twice changes zero rows the second time.
update tickets t
set product_id = p.id
from products p where p.code = t.product_code and t.product_id is null;


select * from tickets