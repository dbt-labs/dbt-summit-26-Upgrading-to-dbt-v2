{#
  QUARANTINED 2026-03-11.

  Disabled during the Q1 close incident when it started returning duplicate
  rows. Nobody has come back to it since, so the SQL below is exactly as it was
  when it was switched off.

  Re-enable with:  --vars 'include_quarantined: true'
#}

select
    shop_id,
    shop_region,
    channel,
    count(distinct orders.order_id) as order_count,
    sum(gross_amount_gold) as gross_revenue_gold

from {{ ref('int_orders_enriched') }} as orders
left join {{ ref('int_order_item_totals') }} as item_totals
    on orders.order_id = item_totals.order_id

group by
    orders.shop_id,
    orders.shop_region,
    orders.channel