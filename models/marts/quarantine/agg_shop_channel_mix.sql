{#
  Order and revenue mix by shop and channel.

  Un-quarantined 2026-09-02. Two defects, both surfaced by Core v2 static
  analysis and both invisible to dbt Core's compile:
    * bare order_id inside count(distinct ...) -- ambiguous across the join
    * channel selected without appearing in the GROUP BY, which is what
      produced the duplicate rows that got this model switched off
#}

select
    orders.shop_id,
    orders.shop_region,
    orders.channel,
    count(distinct orders.order_id) as order_count,
    sum(item_totals.gross_amount_gold) as gross_revenue_gold

from {{ ref('int_orders_enriched') }} as orders
left join {{ ref('int_order_item_totals') }} as item_totals
    on orders.order_id = item_totals.order_id

group by
    orders.shop_id,
    orders.shop_region,
    orders.channel
