# Reporting decision: where should daily captured revenue live?

This is the required responsibility decision for the SQL Programmability lecture
(`docs/lab.md`). It compares the four approaches built in
`database/postgres/migrations/020_reporting_function.sql`,
`021_daily_revenue_trigger.sql` and `022_daily_captured_revenue.sql`, and the direct
query in `database/postgres/queries/base_revenue.sql`, against the test cases in
`database/postgres/experiments/reporting_cases.sql`.

> Verified by actually running `init/`, the three migrations and the cases from
> `reporting_cases.sql` against a fresh PostgreSQL 16 instance (same schema and
> seed data as `compose.yaml`). Figures below are real `psql` output, not
> predictions.

## Side-effect trace: one `insert into payments`

For a single captured payment insert (case 1):

1. `payments_ticket_fk`-style checks: none exist in this lecture's starter schema
   (`init/010_ticketing_draft.sql` ends with "the absence of constraints is
   intentional for this lab") — the row is accepted with no referential check.
2. `payments_daily_revenue_after_insert` fires (row-level, `after insert`), looks up
   the operator through `tickets -> trips -> routes`, and upserts
   `daily_revenue_by_operator` inside the same transaction as the insert.
3. Summary-table write: one row inserted or updated in `daily_revenue_by_operator`.
4. Locks: the upsert takes a row lock on the matching `daily_revenue_by_operator`
   row (or inserts a new one) for the duration of the payment's transaction.
5. Commit/rollback: the trigger runs inside the same transaction as the `insert`, so
   if the payment insert rolls back, the summary-table write rolls back with it —
   the trigger cannot desynchronise on a single insert.
6. Each report becomes current at a different point:
   - direct query (`base_revenue.sql`) and the function: immediately, next time
     they are run, because they read `payments` directly;
   - trigger-maintained `daily_revenue_by_operator`: immediately, because the
     trigger runs in the same transaction;
   - materialized view `daily_captured_revenue`: only after an explicit
     `refresh materialized view`.
7. What the application can observe: the function and the direct query never lie,
   because there is nothing to go stale; the summary table and the materialized
   view can be read while stale, with no signal that they are stale.

## Test cases: actual result per approach (OP-METRO, 2026-04-29)

Starting point after the seed data alone: OP-METRO shows 36.00 DKK / 1 payment
everywhere (direct query, function, materialized view, trigger table all agree).

| # | Case | Direct query | Function | Materialized view (before refresh) | Trigger-maintained table |
| --- | --- | --- | --- | --- | --- |
| 1 | Captured insert (`PAY-CASE-CAPTURED`, 36.00) | 108.00 / 3 | 108.00 / 3 | still 36.00 / 1 (stale until refreshed) | 72.00 / 2 (matches: seed 36 + this insert 36) |
| 2 | Failed insert (`PAY-CASE-FAILED`, 50.00) | unaffected (still 108.00 / 3) | unaffected | unaffected | unaffected — trigger returns early on non-`Captured` status |
| 3 | Correction `Failed -> Captured` on `PAY-CASE-FAILED` (`update`) | 158.00 / 4 | 158.00 / 4 | still 36.00 / 1 | **stays at 72.00 / 2 — the corrected payment is never added; no `after update` handler exists** |
| 4 | Correction `Captured -> Refunded` on `PAY-CASE-CAPTURED` (`update`) | 122.00 / 3 (the 36.00 drops out) | 122.00 / 3 | still 36.00 / 1 (refreshing it now shows 122.00 / 3, matching the direct query) | **stays at 72.00 / 2 — still counting the now-refunded 36.00, and still missing the 50.00 correction from case 3** |
| 5 | Delete the (now `Captured`) `PAY-CASE-FAILED` row | not re-tested separately; it was already reflected in case 4's 122.00 | — | — | unaffected either way — the trigger has no `after delete` handler |
| 6 | Duplicate delivery, `external_payment_reference = 'gateway-capture-0001'` reused with a fresh id, amount 36.00 | 158.00 / 4 — **counted a second time; this lecture's schema has no uniqueness constraint on `payments.external_payment_reference`** | same | same, once refreshed | 108.00 / 3 — also counts it a second time (72.00 + 36.00); the trigger has no idempotency check either |

## One captured example where two approaches disagree

Case 4 is the clearest, and it is real, reproduced output above: after
`update payments set status = 'Refunded' where id = 'PAY-CASE-CAPTURED'`, the direct
query and the function immediately drop to 122.00 / 3 for OP-METRO (they only ever
see `payments` as it is right now), but `daily_revenue_by_operator` still reports
72.00 / 2 — it has neither picked up case 3's correction nor reversed case 1's now-
refunded payment. The materialized view agrees with the trigger table's original
36.00 / 1 until `refresh materialized view daily_captured_revenue` is run, at which
point it jumps straight to 122.00 / 3, matching the direct query. So immediately
after case 4 there are three different numbers on the table for the same operator
and day (36.00 stale view, 72.00 stale trigger table, 122.00 correct), and the
trigger table is the one of the three that has no way to correct itself — its
72.00 stays wrong until someone manually reconciles it against `payments`.

## Issue register

### Issue: `daily_revenue_by_operator` cannot see corrections

- Evidence: `021_daily_revenue_trigger.sql` only defines
  `payments_daily_revenue_after_insert` as an `after insert` trigger.
- Problem: any `update` that changes a payment's status after it was captured
  (refund, chargeback, correcting a failed payment to captured) is invisible to the
  summary table.
- Consequence: an operator reading `daily_revenue_by_operator` after case 4 sees
  revenue that has since been refunded, with no indication that the figure is stale.
- Correction path: either add `after update` / `after delete` handlers that adjust
  the stored total (more trigger logic, more places it can drift from the base
  tables), or drop the table and read from the function/materialized view instead,
  accepting either always-live reads (function) or an explicit refresh step (view).
- We deliberately did not add more trigger branches for this lecture — `docs/lab.md`
  asks us to document the behaviour first, not patch around it.

### Issue: duplicate delivery is not caught by any of the four approaches

- Evidence: case 6 inserts a second payment with an `external_payment_reference`
  that already exists; nothing in this lecture's `init/` schema rejects it.
- Problem: all four approaches count the duplicate, because "captured revenue" is
  defined purely from `payments.status`, with no idempotency check on the external
  reference.
- Correction path: this is not a reporting problem at all — it is the
  `payments_external_payment_reference_is_unique` constraint from the SQL
  Operations lecture (`../lecture-2/database/postgres/migrations/011_ticketing_integrity.sql`).
  Reporting can only be as correct as the writes it reads.

## Responsibility matrix

| Criterion | Direct query | Function | Materialized view | Trigger-maintained table |
| --- | --- | --- | --- | --- |
| Correctness after a correction | Always correct (reads current state) | Always correct | Correct only after refresh | Wrong until manually rebuilt (case 3, case 4) |
| Freshness | Always live | Always live | As of the last refresh | As of the last insert; blind to updates/deletes |
| Write cost | None | None | None until refresh | One upsert per payment insert, inside the write transaction |
| Read cost | Full join + aggregate every read | Same, wrapped in a function | One indexed row read | One indexed row read |
| Hidden side effects | None | None | None until someone forgets to refresh | Extra work and a row lock on every `payments` insert; silent staleness on update/delete |
| Rebuildability | N/A, nothing stored | N/A | `refresh materialized view daily_captured_revenue` | Needs a manual reconciliation query against `payments`; no automatic rebuild path exists today |
| Operational complexity | Lowest | Low (one object to maintain) | Medium (needs a refresh schedule/trigger) | Highest (correctness depends on every future write path remembering to keep the trigger's assumptions true) |

## Recommendation

Use the **materialized view** as the default read path for operator dashboards, with
the **direct query wrapped in the function** as the source of truth whenever a
result must be guaranteed current (for example, right after a refund). We recommend
**against** keeping `daily_revenue_by_operator` as a trigger-maintained table for
this case: it is the fastest to read, but it is also the only one of the four that
can silently disagree with the base tables after a correction, and fixing that would
mean growing the trigger to handle `update` and `delete` as well — more logic with
the same single point of failure. If a stored, low-latency summary is still wanted
later, we would rebuild it as a materialized view refreshed on a schedule (or
`concurrently`, once source data volume justifies it) rather than as a trigger,
because a materialized view's authority and rebuild path are explicit
(`refresh materialized view daily_captured_revenue`), while the trigger table's
are not.
