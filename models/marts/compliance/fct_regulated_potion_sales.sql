{#
  Regulator-facing extract of sales for Guild-regulated potions.

  Built with the house `audit_table` materialization so every rebuild is stamped
  into merlinco_build_ledger for Compliance.
#}

with order_items as (

    select * from {{ ref('fct_order_items') }}

),

regulated_only as (

    select
        order_item_id,
        order_id,
        potion_sku,
        potion_name,
        potion_category,
        customer_id,
        shop_id,
        shop_region,
        ordered_at,
        quantity,
        unit_price_gold,
        gross_line_amount_gold

    from order_items
    where is_regulated
      and order_status = 'completed'

),

final as (

    select
        regulated_only.*,
        date_trunc('quarter', regulated_only.ordered_at) as reporting_quarter

    from regulated_only

)

select * from final
