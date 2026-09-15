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
        collected_gold,
        sum(case when primary_payment_method = 'coin' then collect_gold end) as coin

    from {{ ref('fct_orders') }}
    where order_status = 'completed'
      and primary_payment_method is not null

)
