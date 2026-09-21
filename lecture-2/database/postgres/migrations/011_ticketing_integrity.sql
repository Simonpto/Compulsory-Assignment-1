-- Copy this file to 011_ticketing_integrity.sql and complete it from your integrity map.
-- Keep the starter DDL unchanged.

begin;

alter table trips
    alter column capacity set not null,
    alter column reserved_seats set not null,
    add constraint trips_capacity_non_negative
        check (capacity >= 0),
    add constraint trips_reserved_seats_valid
        check (reserved_seats between 0 and capacity);

alter table tickets
    add constraint tickets_user_fk
        foreign key (user_id) references users(id),
    add constraint tickets_trip_fk
        foreign key (trip_id) references trips(id),
    add constraint tickets_from_is_before_to
        check ( valid_to_utc > valid_from_utc ),
    add constraint tickets_ticket_code_unique
        unique (ticket_code),
    add constraint tickets_check_status
        check (status in ('Active', 'Validated'));

alter table products
    add constraint tickets_amount_not_negative
        check (price >= 0 );

alter table payments
    add constraint payments_ticket_fk
        foreign key (ticket_id) references tickets(id),
    add constraint payments_external_payment_reference_is_unique
        unique(external_payment_reference);

alter table tickets
    add constraint tickets_id_ticket_code_unique
        unique (id, ticket_code);
alter table validations
    add constraint validations_ticket_fk
        foreign key (ticket_id, ticket_code) references tickets (id, ticket_code);

-- Product reference: a ticket must point at a real catalogue product.
alter table tickets
    add constraint tickets_product_fk
        foreign key (product_code) references products(code);

-- Currency: must be present and consistently represented (3-letter ISO-style code).
alter table products
    alter column currency set not null,
    add constraint products_currency_valid
        check (currency ~ '^[A-Z]{3}$');

alter table tickets
    alter column currency set not null,
    add constraint tickets_currency_valid
        check (currency ~ '^[A-Z]{3}$');

alter table payments
    alter column currency set not null,
    add constraint payments_currency_valid
        check (currency ~ '^[A-Z]{3}$');

-- Not solved by a row-level constraint (see docs/integrity-map-template.md, Issue 2,
-- and the "Important boundary" section of docs/lab.md):
--   * two concurrent purchases can both pass trips_reserved_seats_valid and still
--     oversell a trip, because the CHECK only sees one row at commit time;
--   * a disabled user placing a ticket, and duplicate validations.ticket_code across
--     unrelated tickets, are domain decisions, not column constraints.
-- These are kept open on purpose and carried forward to the transactions lecture.

commit;
