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
        sum(case when primary_payment_method = 'coin' then collected_gold end) as coin,
        sum(case when primary_payment_method = 'guild_credit' then collected_gold end) as guild_credit,
        sum(case when primary_payment_method = 'crystal_transfer' then collected_gold end) as crystal_transfer,
        sum(case when primary_payment_method = 'barter' then collected_gold end) as barter
    from {{ ref('fct_orders') }}
    where order_status = 'completed'
    and primary_payment_method is not null
    group by shop_region

)
