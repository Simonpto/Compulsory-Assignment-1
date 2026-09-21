-- Copy to 030_expand_product_identity.sql and complete it.
-- Add a stored UUID to each product and a unique key.
-- Add the nullable ticket reference and a NOT VALID foreign key.
-- Keep the original product code contract usable.

begin;
set local lock_timeout = '3s';

alter table products add id UUID unique default gen_random_uuid();

alter table tickets add product_id UUID;

Alter table tickets add constraint fk_product_ID FOREIGN KEY (product_id) REFERENCES products(id) not valid ;

commit;
