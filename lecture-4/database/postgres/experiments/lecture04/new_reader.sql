-- Resolves product_id when it is already set; otherwise looks the product up
-- by product_code. Before the backfill runs, this still resolves every
-- original ticket through the old product_code path.
select t.id, t.product_code, coalesce(t.product_id, p.id) as resolved_product_id , t.price, t.currency
from tickets t
left join products p on t.product_id is null and p.code = t.product_code
order by t.id;
