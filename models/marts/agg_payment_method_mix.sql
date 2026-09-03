{{
    config(
        materialized = 'table'
    )
}}

{#
  Collected revenue by region, split into one column per payment method.

  Uses Snowflake's dynamic PIVOT so finance can add a payment method without
  anybody editing this model -- `in (any ...)` resolves the column list from the
  data at query time rather than from a list maintained here.
#}

select *
from (

    select
        shop_region,
        primary_payment_method,
        collected_gold

    from {{ ref('fct_orders') }}
    where order_status = 'completed'
      and primary_payment_method is not null

)
pivot (
    sum(collected_gold)
    for primary_payment_method in (any order by primary_payment_method)
) as pivoted
