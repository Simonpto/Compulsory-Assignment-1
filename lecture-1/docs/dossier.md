# Modelling dossier

## Route-stop primary key

We chose a composite primary key on `route_stops (route_id, stop_sequence)` rather than
`(route_id, stop_id)`. This lets a route visit the same physical stop more than once
(see `docs/Task1.md`), which the M2 seed data demonstrates: `STOP-KONGENS-NYTORV`
appears at both `stop_sequence = 2` and `stop_sequence = 4` on `LINE-M2`.

Functional dependency: `(route_id, stop_sequence) -> stop_id`. A stop's position on a
route determines which physical stop it is, but the reverse does not hold, since one
stop can occur at more than one sequence position on the same route. This is exactly
why `stop_id` alone cannot be part of the key.

## Assumption that may change later

We predict we will change the timestamp columns so the service date is not duplicated
inside `scheduled_departure_utc` (currently `trips.service_date` and the date portion of
`trips.scheduled_departure_utc` can drift apart if one is updated without the other).
A later lecture may derive `service_date` from `scheduled_departure_utc` instead of
storing both.
