{#
  Order header widened with shop and customer attributes. This is the join that
  every downstream order fact reads from.
#}

with orders as (

    select * from {{ ref('stg_abra_pos__orders') }}

),

shops as (

    select * from {{ ref('stg_alembic_ops__shops') }}

),

customers as (

    select * from {{ ref('stg_grimoire_crm__customers') }}

),

joined as (

    select
        orders.order_id,
        orders.customer_id,
        orders.shop_id,
        orders.ordered_at,
        orders.order_status,
        orders.channel,
        orders.discount_copper,
        orders.discount_gold,
        shops.shop_name,
        shops.region as shop_region,
        shops.city as shop_city,
        customers.full_name as customer_name,
        customers.home_region as customer_home_region,
        customers.favored_discipline

    from orders
    left join shops
        on orders.shop_id = shops.shop_id
    left join customers
        on orders.customer_id = customers.customer_id

)

select * from joined
