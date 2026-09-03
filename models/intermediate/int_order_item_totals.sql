{#
  Order lines rolled up to the order grain so the order fact can carry basket
  metrics without re-joining the line table.
#}

with order_items as (

    select * from {{ ref('stg_abra_pos__order_items') }}

),

aggregated as (

    select
        order_id,
        count(*) as line_count,
        sum(quantity) as total_quantity,
        sum(gross_line_amount_copper) as gross_amount_copper

    from order_items
    group by order_id

)

select
    order_id,
    line_count,
    total_quantity,
    gross_amount_copper,
    {{ copper_to_gold('gross_amount_copper') }} as gross_amount_gold

from aggregated
