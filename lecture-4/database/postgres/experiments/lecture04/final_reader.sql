-- Joins products through product_id only and includes the product code from
-- products.code. Does not reference tickets.product_code, so this query still
-- works after that column is dropped (see remove_legacy.sql).
select t.id, t.product_id, t.price, t.currency, p.code
from tickets t
         join products p on p.id = t.product_id
order by t.id;
