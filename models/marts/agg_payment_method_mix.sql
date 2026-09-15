{{
    config(
        materialized = 'table'
    )
}}

{#
  Collected revenue by region, split into one column per governed payment method.

  The staging accepted_values test guards this declared list so the model keeps
  a statically knowable schema while still surfacing newly introduced methods.
#}

{% set payment_methods = ['barter', 'coin', 'crystal_transfer', 'guild_credit'] %}

select
    shop_region,
    {% for method in payment_methods %}
    sum(
        case
            when primary_payment_method = '{{ method }}' then collected_gold
            else 0
        end
    ) as collected_gold_{{ method }},
    {% endfor %}
    sum(collected_gold) as collected_gold_total

from {{ ref('fct_orders') }}
where order_status = 'completed'
  and primary_payment_method is not null
group by shop_region
