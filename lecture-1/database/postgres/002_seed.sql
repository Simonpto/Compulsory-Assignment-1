insert into operators (id, name) values
    ('OP-METRO', 'City Metro'),
    ('OP-BUS', 'City Bus')
on conflict do nothing;

insert into routes (id, operator_id, city_id, mode, short_name) values
    ('LINE-M2', 'OP-METRO', 'CPH', 'metro', 'M2'),
    ('LINE-5C', 'OP-BUS', 'CPH', 'bus', '5C')
on conflict do nothing;

insert into stops (id, city_id, name) values
    ('STOP-NORREPORT', 'CPH', 'Nørreport'),
    ('STOP-KONGENS-NYTORV', 'CPH', 'Kongens Nytorv'),
    ('STOP-AIRPORT', 'CPH', 'Copenhagen Airport'),
    ('STOP-CENTRAL', 'CPH', 'Copenhagen Central Station')
on conflict do nothing;

insert into route_stops (route_id, stop_id, stop_sequence) values
   ('LINE-M2', 'STOP-NORREPORT', 1),
   ('LINE-M2', 'STOP-KONGENS-NYTORV', 2),
   ('LINE-M2', 'STOP-CENTRAL', 3),
   ('LINE-M2', 'STOP-KONGENS-NYTORV', 4),
   ('LINE-5C', 'STOP-CENTRAL', 1),
   ('LINE-5C', 'STOP-AIRPORT', 2)
on conflict do nothing;

insert into trips (id, route_id, service_date, scheduled_departure_utc, status) values
    ('T1', 'LINE-M2', '2026-08-28', '2026-08-28 07:00:00', 'Scheduled'),
    ('T2', 'LINE-M2', '2026-08-28', '2026-08-28 07:15:00', 'Scheduled'),
    ('T3', 'LINE-M2', '2026-08-28', '2026-08-28 07:30:00', 'Scheduled'),
    ('T4', 'LINE-M2', '2026-08-28', '2026-08-28 07:45:00', 'Scheduled'),
    ('T5', 'LINE-M2', '2026-08-28', '2026-08-28 08:00:00', 'Scheduled'),
    ('T6', 'LINE-5C', '2026-08-28', '2026-08-28 07:00:00', 'Scheduled'),
    ('T7', 'LINE-5C', '2026-08-28', '2026-08-28 08:00:00', 'Scheduled')
on conflict do nothing;