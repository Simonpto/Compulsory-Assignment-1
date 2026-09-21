# MobilityTicketing — Compulsory Assignment 1

One PostgreSQL slice of a city mobility-ticketing platform, built across four
lectures: relational modelling, integrity constraints, reporting programmability,
and a zero-downtime product-identity migration. Each lecture keeps its own
Docker Compose stack (the schemas are deliberately incompatible across weeks), so
each subfolder is started independently.

Submitted commit: _fill in with `git rev-parse HEAD` after your final commit_
Setup and reset instructions: run `docker compose up -d` inside the relevant
`lecture-N/` folder, then `docker compose down -v && docker compose up -d` to
replay its `database/postgres/init/` (or `database/postgres/`, for lecture 1)
from empty. Each lecture's own `README.md` has the exact commands used to apply
its migrations.

## Where to find the work

**Lecture 1 — model, workload map and queries:** schema in
[`lecture-1/database/postgres/001_relational_baseline.sql`](lecture-1/database/postgres/001_relational_baseline.sql),
seed in [`002_seed.sql`](lecture-1/database/postgres/002_seed.sql), the three
workload queries in
[`003_queries.sql`](lecture-1/database/postgres/003_queries.sql), the key
decision and functional dependency in
[`lecture-1/docs/dossier.md`](lecture-1/docs/dossier.md) and
[`lecture-1/docs/Task1.md`](lecture-1/docs/Task1.md).

**Lecture 2 — constraints and tests:** migration in
[`lecture-2/database/postgres/migrations/011_ticketing_integrity.sql`](lecture-2/database/postgres/migrations/011_ticketing_integrity.sql),
negative-write tests in
[`constraints_should_fail.sql`](lecture-2/database/postgres/experiments/constraints_should_fail.sql)
(12 cases, each verified against a live database), full integrity map and issue
register in
[`lecture-2/docs/integrity-map-template.md`](lecture-2/docs/integrity-map-template.md).

**Lecture 3 — reporting experiment and comparison:** the four approaches in
[`lecture-3/database/postgres/migrations/`](lecture-3/database/postgres/migrations)
and [`queries/base_revenue.sql`](lecture-3/database/postgres/queries/base_revenue.sql),
test cases in
[`reporting_cases.sql`](lecture-3/database/postgres/experiments/reporting_cases.sql),
and the responsibility matrix, side-effect trace, issue register and
recommendation — with real, reproduced query output — in
[`lecture-3/docs/reporting-decision.md`](lecture-3/docs/reporting-decision.md).

**Lecture 4 — migration stages and verification:** the expand/backfill/require
migrations in
[`lecture-4/database/postgres/migrations/`](lecture-4/database/postgres/migrations),
the old/new/final reader and writer scripts in
[`experiments/lecture04/`](lecture-4/database/postgres/experiments/lecture04),
and the full stage-by-stage evidence (including the TICKET-3 price check) in
[`lecture-4/docs/evidence/lecture04/README.md`](lecture-4/docs/evidence/lecture04/README.md).

## Two decisions worth discussing

**1. Letting a route visit the same stop twice, via a `(route_id,
stop_sequence)` key.** We keyed `route_stops` on `(route_id, stop_sequence)`
rather than `(route_id, stop_id)`. The alternative — one row per stop per route —
is simpler and is enough for a route that never repeats a stop, but it cannot
represent a real loop line that passes the same physical stop twice (our M2 seed
data does exactly this, at sequence 2 and 4). The chosen key fits MobilityTicketing
because ordered-stop queries and "next trip" queries always need a position on the
route, not just membership; see
[`lecture-1/database/postgres/003_queries.sql`](lecture-1/database/postgres/003_queries.sql),
query 2, and the functional dependency note in
[`lecture-1/docs/dossier.md`](lecture-1/docs/dossier.md).

**2. Not keeping the trigger-maintained `daily_revenue_by_operator` table.** We
built all four reporting approaches, then recommended the materialized view (fast
reads, explicit refresh) backed by the function (always-correct reads) over the
trigger-maintained summary table. The alternative — extend the trigger with
`after update`/`after delete` handlers — was rejected: we reproduced a real case
where a payment correction (`Captured` → `Refunded`) leaves the trigger table
silently wrong (72.00 DKK for OP-METRO where the true figure was 122.00 DKK),
while the direct query and function are always correct and the materialized view
is correct as of its last refresh. See
[`lecture-3/docs/reporting-decision.md`](lecture-3/docs/reporting-decision.md) for
the full comparison and reproduced output.

## One limitation or open question

Our constraints do not guarantee that a trip cannot be oversold. The `CHECK
(reserved_seats BETWEEN 0 AND capacity)` constraint on `trips` (see
[`lecture-2/database/postgres/migrations/011_ticketing_integrity.sql`](lecture-2/database/postgres/migrations/011_ticketing_integrity.sql))
only ever sees one row at commit time: two concurrent purchases can both read
`reserved_seats = capacity - 1`, both compute a valid increment, and both commit,
oversubscribing the trip while every individual write still satisfies the CHECK.
This is documented as Issue 2 in
[`lecture-2/docs/integrity-map-template.md`](lecture-2/docs/integrity-map-template.md).
What we would check next: whether the transactions lecture expects row-level
locking (`select ... for update`), `serializable` isolation, or an atomic
conditional update (`update trips set reserved_seats = reserved_seats + 1 where
id = ... and reserved_seats < capacity`, checked for affected row count) — each has
a different cost under contention, and we have not yet measured which one this
case needs.
