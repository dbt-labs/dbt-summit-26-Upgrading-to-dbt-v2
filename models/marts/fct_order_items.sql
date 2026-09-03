{{
    config(
        materialized = 'table'
    )
}}

with order_items as (

    select * from {{ ref('stg_abra_pos__order_items') }}

),

orders as (

    select * from {{ ref('int_orders_enriched') }}

),

potions as (

    select * from {{ ref('stg_abra_pos__potions') }}

),

final as (

    select
        order_items.order_item_id,
        order_items.order_id,
        order_items.potion_sku,
        orders.customer_id,
        orders.shop_id,
        orders.shop_region,
        orders.ordered_at,
        orders.order_status,
        potions.potion_name,
        potions.category as potion_category,
        potions.is_regulated,
        order_items.quantity,
        order_items.unit_price_copper,
        order_items.unit_price_gold,
        order_items.gross_line_amount_copper,
        order_items.gross_line_amount_gold

    from order_items
    inner join orders
        on order_items.order_id = orders.order_id
    left join potions
        on order_items.potion_sku = potions.potion_sku

)

select * from final
