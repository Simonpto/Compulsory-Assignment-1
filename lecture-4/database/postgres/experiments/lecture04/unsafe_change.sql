-- Use only your disposable lab database. Predict the failure first.
begin;

alter table tickets drop column product_code;

select id, product_code, price, currency
from tickets
order by id;
-- What information would you need to reconstruct the product links?

rollback;
-- If psql stops on the expected error, the connection closing rolls back
-- this transaction. In an interactive session, issue ROLLBACK yourself.

