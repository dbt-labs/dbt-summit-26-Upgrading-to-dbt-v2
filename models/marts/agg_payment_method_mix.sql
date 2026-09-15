{{
    config(
        materialized = 'table'
    )
}}

{#
  Collected revenue by region, split into one column per governed payment method.

  Keep these expressions aligned with the accepted-values test on
  stg_abra_pos__payments.payment_method. Conditional aggregation allows dbt v2
  to validate the model in strict mode and keeps the output schema stable.
#}

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