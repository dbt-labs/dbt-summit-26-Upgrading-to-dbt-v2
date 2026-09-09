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

{% set payment_methods = ['barter', 'coin', 'crystal_transfer', 'guild_credit'] %}

select
    shop_region,
    {% for method in payment_methods %}
    sum(case when primary_payment_method = '{{ method }}' then collected_gold else 0 end)
        as collected_gold_{{ method }},
    {% endfor %}
    sum(collected_gold) as collected_gold_total
from {{ ref('fct_orders') }}
group by shop_region