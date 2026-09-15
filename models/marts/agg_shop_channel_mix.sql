{#
  QUARANTINED 2026-03-11.

  Disabled during the Q1 close incident when it started returning duplicate
  rows. Nobody has come back to it since, so the SQL below is exactly as it was
  when it was switched off -- mid-edit, adding order_count to the courier_owl
  branch.

  Re-enable with:  --vars 'include_quarantined: true'
#}

{{
    config(
        enabled = var('include_quarantined', false),
        tags = ['quarantined']
    )
}}

with orders as (

    select * from {{ ref('int_orders_enriched') }}

),

item_totals as (

    select * from {{ ref('int_order_item_totals') }}

),

in_store as (

    select
        orders.shop_region,
        date_trunc('month', orders.ordered_at) as order_month,
        sum(item_totals.gross_amount_gold) as gross_revenue_gold,
        count(distinct orders.order_id) as order_count

    from orders
    left join item_totals
        on orders.order_id = item_totals.order_id
    where orders.channel = 'in_store'
    group by orders.shop_region, order_month

),

courier_owl as (

    select
        orders.shop_region,
        date_trunc('month', orders.ordered_at) as order_month,
        sum(item_totals.gross_amount_gold) as gross_revenue_gold,
        count(distinct orders.order_id) as order_count


    from orders
    left join item_totals
        on orders.order_id = item_totals.order_id
    where orders.channel = 'courier_owl'
    group by orders.shop_region, order_month

)

select * from in_store
union all
select * from courier_owl
