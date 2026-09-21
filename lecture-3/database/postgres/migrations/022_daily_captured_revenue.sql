-- Copy this file to 022_daily_captured_revenue.sql and apply it.

create materialized view daily_captured_revenue as
select
    r.operator_id,
    p.created_utc::date as revenue_date,
    sum(p.amount) as captured_amount,
    count(*) as captured_payments
from payments p
join tickets t on t.id = p.ticket_id
join trips tr on tr.id = t.trip_id
join routes r on r.id = tr.route_id
where p.status = 'Captured'
group by r.operator_id, p.created_utc::date
with no data;

create unique index daily_captured_revenue_key
    on daily_captured_revenue (operator_id, revenue_date);

-- Run explicitly when the source data should become visible:
refresh materialized view daily_captured_revenue;

select * from daily_captured_revenue;


insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status, created_utc
) values
    ('PAYMENT-3', 'USER-1', 'TICKET-1', 'gateway-capture-0001', 36.00, 'DKK', 'Captured', '2026-04-29 07:40:00+00')
on conflict do nothing;