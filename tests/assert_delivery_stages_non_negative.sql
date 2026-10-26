-- Total elapsed time and transit time must be non-negative.
--
-- days_to_carrier is deliberately excluded: approved_at is populated by a
-- nightly batch process (values cluster at ~23:30), so it frequently post-dates
-- the physical carrier handoff. 674 of 96,470 orders are affected. Those rows
-- are flagged via has_timestamp_anomaly rather than removed.

select
    order_id,
    days_in_transit,
    days_total

from {{ ref('fct_order_delivery') }}

where days_in_transit < 0
   or days_total < 0
