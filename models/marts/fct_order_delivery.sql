with orders as (

    select * from {{ ref('stg_orders') }}
    where order_status = 'delivered'
      and delivered_at is not null
      and estimated_delivery_at is not null
      and purchased_at is not null
      -- Exclude 20 records (0.02%) where delivery pre-dates carrier handoff.
      -- Physically impossible and unexplained, unlike the batch-written
      -- approved_at issue; transit metrics from these rows are meaningless.
      and delivered_at >= handed_to_carrier_at

),

items_per_order as (

    select
        order_id,
        count(*)                  as item_count,
        count(distinct seller_id) as seller_count,
        sum(item_price)           as order_value,
        sum(item_freight_cost)    as freight_cost

    from {{ ref('stg_order_items') }}
    group by 1

),

final as (

    select
        o.order_id,
        o.customer_id,

        o.purchased_at,
        o.approved_at,
        o.handed_to_carrier_at,
        o.delivered_at,
        o.estimated_delivery_at,

        i.item_count,
        i.seller_count,
        i.order_value,
        i.freight_cost,

        date_diff('day', o.purchased_at, o.approved_at)          as days_to_approve,
        date_diff('day', o.approved_at, o.handed_to_carrier_at)  as days_to_carrier,
        date_diff('day', o.handed_to_carrier_at, o.delivered_at) as days_in_transit,
        date_diff('day', o.purchased_at, o.delivered_at)         as days_total,

        date_diff('day', o.estimated_delivery_at, o.delivered_at) as days_vs_estimate,

        cast(o.delivered_at as date) <= cast(o.estimated_delivery_at as date) as is_on_time,

        -- approved_at is written by a nightly batch (most values cluster at ~23:30),
        -- so it can post-date the physical carrier handoff. Flag rather than drop:
        -- downstream users can exclude these when stage durations matter.
        date_diff('day', o.approved_at, o.handed_to_carrier_at) < 0
            or date_diff('day', o.handed_to_carrier_at, o.delivered_at) < 0
            as has_timestamp_anomaly

    from orders o
    left join items_per_order i on o.order_id = i.order_id

)

select * from final
