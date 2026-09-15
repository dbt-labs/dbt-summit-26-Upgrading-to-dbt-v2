{{
    config(
        materialized = 'table'
    )
}}

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
    for primary_payment_method in ('coin', 'guild_credit', 'crystal_transfer')
) as pivoted