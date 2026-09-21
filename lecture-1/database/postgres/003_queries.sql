-- Query 1: upcoming trips
select
    t.id,
    t.scheduled_departure_utc,
    t.status
from trips t
where t.route_id = 'LINE-M2'
  and t.scheduled_departure_utc >= '2026-08-28 06:00:00'
order by t.scheduled_departure_utc
limit 20;

-- Query 2: ordered route stops
select rs.route_id, rs.stop_id, rs.stop_sequence, s.name
from route_stops rs
    inner join stops s on s.id = rs.stop_id
order by rs.stop_sequence;

-- Query 3: routes and trip count, including routes with zero trips
select r.*, count(t.*) as trip_count
from routes r
    left join trips t on t.route_id = r.id and t.service_date = '2026-08-28'
group by r.id;
