{{
    config(
        materialized = 'table'
    )
}}

with orders as (

    select * from {{ ref('int_orders_enriched') }}

),

item_totals as (

    select * from {{ ref('int_order_item_totals') }}

),

order_payments as (

    select * from {{ ref('int_order_payments') }}

),

final as (

    select
        orders.order_id,
        orders.customer_id,
        orders.shop_id,
        orders.ordered_at,
        orders.order_status,
        orders.channel,
        {{ is_weekend('orders.ordered_at') }} as is_weekend_order,
        orders.shop_name,
        orders.shop_region,
        orders.customer_name,

        item_totals.line_count,
        item_totals.total_quantity,
        item_totals.gross_amount_copper,
        item_totals.gross_amount_gold,

        orders.discount_copper,
        item_totals.gross_amount_copper - orders.discount_copper as net_amount_copper,
        {{ copper_to_gold('item_totals.gross_amount_copper - orders.discount_copper') }} as net_amount_gold,

        coalesce(order_payments.collected_copper, 0) as collected_copper,
        coalesce(order_payments.collected_gold, 0) as collected_gold,
        coalesce(order_payments.refunded_gold, 0) as refunded_gold,
        coalesce(order_payments.payment_attempt_count, 0) as payment_attempt_count,
        coalesce(order_payments.failed_payment_count, 0) as failed_payment_count,
        order_payments.primary_payment_method,
        order_payments.last_payment_at,

        {{ audit_columns() }}

    from orders
    left join item_totals
        on orders.order_id = item_totals.order_id
    left join order_payments
        on orders.order_id = order_payments.order_id

)

select * from final
