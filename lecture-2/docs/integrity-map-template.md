# Integrity map

| Invariant | Affected tables and columns | Current protection | Missing protection or limitation | Expected failure behaviour | Evidence |
| --- | --- | --- | --- | --- | --- |
| Capacity cannot be negative | `trips.capacity` | CHECK `trips_capacity_non_negative` | None at row level | SQLSTATE 23514 | Test #1 |
| Reserved seats cannot be negative or exceed capacity | `trips.capacity`, `trips.reserved_seats` | CHECK `trips_reserved_seats_valid` | Only guards one row; two concurrent purchases can both read the same remaining capacity and both pass this check | SQLSTATE 23514 | Test #2 |
| A ticket must reference an existing trip | `tickets.trip_id` → `trips.id` | FK `tickets_trip_fk` | None | SQLSTATE 23503 | Test #3 |
| A ticket must reference an existing user | `tickets.user_id` → `users.id` | FK `tickets_user_fk` | Does not check `users.is_disabled` — a disabled user can still get a valid ticket | No error currently (gap) | Not directly tested by numbered statements |
| Ticket validity end cannot be earlier than start | `tickets.valid_from_utc`, `tickets.valid_to_utc` | CHECK `tickets_from_is_before_to` | None | SQLSTATE 23514 | Test #4 |
| Ticket code must be unique | `tickets.ticket_code` | UNIQUE `tickets_ticket_code_unique` | None | SQLSTATE 23505 | Test #5 |
| Ticket status must come from a known set | `tickets.status` | CHECK `tickets_check_status` | List (`Active`, `Validated`) may not cover all real states, e.g. `Cancelled`, `Expired` — needs domain decision | SQLSTATE 23514 | Test #6 |
| Product price cannot be negative | `products.price` | CHECK `tickets_amount_not_negative` | Constraint name is misleading (says "tickets" but is on `products`); rename recommended | SQLSTATE 23514 | Test #7 |
| A payment must reference an existing ticket | `payments.ticket_id` → `tickets.id` | FK `payments_ticket_fk` | None | SQLSTATE 23503 | Test #8 |
| An external payment reference must not be duplicated | `payments.external_payment_reference` | UNIQUE `payments_external_payment_reference_is_unique` | None | SQLSTATE 23505 | Test #9 |
| A validation's ticket id and ticket code must belong to the same ticket | `validations.ticket_id`, `validations.ticket_code` → `tickets(id, ticket_code)` | Composite FK `validations_ticket_fk` (requires `tickets_id_ticket_code_unique`) | None for the mismatch case itself | SQLSTATE 23503 | Test #10 |
| A ticket must reference a valid product | `tickets.product_code` → `products.code` | FK `tickets_product_fk` | None | SQLSTATE 23503 | Test #11 |
| Currency must be present and consistent | `tickets.currency`, `payments.currency`, `products.currency` | `NOT NULL` + CHECK `tickets_currency_valid` / `payments_currency_valid` / `products_currency_valid` (`currency ~ '^[A-Z]{3}$'`) | Each column is validated on its own; there is still no cross-table check that a ticket's, its payment's and its product's currency all agree | SQLSTATE 23502 (missing) / 23514 (malformed) | Test #12 |
| A validation's ticket code must not be reused ambiguously across different tickets | `validations.ticket_code` | **None implemented** | Composite FK confirms the *pairing* is correct, but does not stop the same code from being scanned/logged under different device/vehicle records if the code itself is duplicated elsewhere | Currently no rejection (gap) — depends on domain decision | Open question in Issue register |

## Issue register

### Issue 1 (resolved)

- Evidence: `tickets.product_code` had no `references products(code)` constraint in the first draft of `011_ticketing_integrity.sql`.
- Problem: A ticket could be created with a `product_code` that does not exist in `products`, so price/currency lookups against the product could silently reference nothing.
- Fix applied: `alter table tickets add constraint tickets_product_fk foreign key (product_code) references products(code);` (see the migration). Test #11 in `constraints_should_fail.sql` shows the rejection.
- Open question that remains: Should a product ever be deletable/deactivated while tickets still reference it? If so, `products` needs a soft-delete flag rather than a hard delete, to avoid breaking historical tickets.

### Issue 2

- Evidence: `trips_reserved_seats_valid` (CHECK `reserved_seats between 0 and capacity`) only evaluates the row as it exists at commit time of a single transaction.
- Problem: Two concurrent ticket purchases can both read `reserved_seats = capacity - 1` before either commits, both compute a valid increment, and both commit successfully — overselling the trip despite the CHECK passing for each individual row.
- Consequence: A trip can end up oversold (more tickets sold than seats), which is exactly the invariant meant to be protected.
- Specific improvement: Cannot be solved with a plain CHECK; needs either `select ... for update` locking on the `trips` row during purchase, a serializable transaction isolation level, or an atomic `update trips set reserved_seats = reserved_seats + 1 where id = ... and reserved_seats < capacity` pattern checked for affected row count. This is explicitly out of scope for this lecture per the assignment's "Important boundary" note.
- Open question: Which concurrency strategy does the course expect for the transactions lecture — row locking, serializable isolation, or an application-level retry/compare-and-swap?

## State-transition trace

### Ticket purchase

1. Row is inserted into `tickets` with `status = 'Active'`, referencing an existing `trip_id` (must satisfy `tickets_trip_fk`), an existing `user_id` (must satisfy `tickets_user_fk`), and an existing `product_code` (not yet enforced — see Issue 1).
2. `trips.reserved_seats` is incremented for the matching trip; must still satisfy `trips_reserved_seats_valid` (`reserved_seats <= capacity`).
3. Row is inserted into `payments` referencing the new ticket's `id` (must satisfy `payments_ticket_fk`), with a unique `external_payment_reference` (must satisfy `payments_external_payment_reference_is_unique`).

### Ticket validation

1. Ticket is looked up by `ticket_code` (relies on `tickets_ticket_code_unique` to guarantee the lookup is unambiguous).
2. `tickets.status` is checked; only tickets in an allowed pre-validation state should be accepted (currently only `Active`/`Validated` exist in the CHECK, so the transition target must already be one of these).
3. Row is inserted into `validations` with `ticket_id` and `ticket_code` matching the same ticket row (enforced by the composite FK `validations_ticket_fk`), and `tickets.status` is updated to `Validated`.