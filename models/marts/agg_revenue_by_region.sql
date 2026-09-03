{{
    config(
        materialized = 'table'
    )
}}

{#
  Region-by-month revenue rollup. Reads the backfill fact so that reprocessing
  runs and nightly runs produce the same shape of output.
#}

with backfill_orders as (

    select * from {{ ref('fct_orders_backfill') }}

),

shops as (

    select * from {{ ref('stg_alembic_ops__shops') }}

),

shop_counts as (

    select
        region,
        count(*) as shop_count

    from shops
    group by region

),

aggregated as (

    select
        shop_region,
        order_month,
        count(distinct order_id) as order_count,
        sum(gross_amount_copper) as gross_revenue_copper,
        sum(gross_amount_gold) as gross_revenue_gold,
        sum(discount_gold) as discount_gold,
        count_if(order_status = 'returned') as returned_order_count

    from backfill_orders
    group by shop_region, order_month

)

select
    aggregated.shop_region,
    aggregated.order_month,
    shop_counts.shop_count,
    aggregated.order_count,
    aggregated.gross_revenue_copper,
    aggregated.gross_revenue_gold,
    aggregated.discount_gold,
    aggregated.returned_order_count,
    round(aggregated.gross_revenue_gold / nullif(shop_counts.shop_count, 0), 2) as gross_revenue_gold_per_shop,

    {{ audit_columns() }}

from aggregated
left join shop_counts
    on aggregated.shop_region = shop_counts.region
