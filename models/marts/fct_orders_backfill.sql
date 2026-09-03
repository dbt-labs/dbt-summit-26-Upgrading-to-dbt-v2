{#
  Reprocessing variant of fct_orders.

  The nightly deploy job leaves PIPELINE_RUN_MODE at its default of "standard",
  which lands this as a table. When the data team reprocesses history they set
  PIPELINE_RUN_MODE=backfill so the model stays ephemeral and does not leave a
  half-written table behind if the backfill is cancelled partway through.
#}

{% set run_mode = var('PIPELINE_RUN_MODE', 'standard') %}

{{
    config(
        materialized = 'ephemeral' if run_mode == 'backfill' else 'table'
    )
}}

with orders as (

    select * from {{ ref('int_orders_enriched') }}

),

item_totals as (

    select * from {{ ref('int_order_item_totals') }}

),

final as (

    select
        orders.order_id,
        orders.shop_region,
        orders.channel,
        orders.order_status,
        orders.ordered_at,
        date_trunc('month', orders.ordered_at) as order_month,
        item_totals.gross_amount_copper,
        item_totals.gross_amount_gold,
        orders.discount_gold,
        '{{ run_mode }}' as pipeline_run_mode

    from orders
    left join item_totals
        on orders.order_id = item_totals.order_id

)

select * from final
