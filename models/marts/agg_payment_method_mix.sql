{{
    config(
        materialized = 'table'
    )
}}

{#
  Collected revenue by region, split into one column per supported payment method.

  The explicit payment-method list keeps the model compatible with dbt static
  analysis. Update this list when a new accepted payment method is introduced.
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
    for primary_payment_method in (
        'barter' as barter,
        'coin' as coin,
        'crystal_transfer' as crystal_transfer,
        'guild_credit' as guild_credit
    )
) as pivoted
