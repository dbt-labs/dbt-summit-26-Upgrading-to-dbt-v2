{{
    config(
        materialized = 'table'
    )
}}

{#
  Collected revenue by region, split into one column per payment method.

  This used Snowflake's dynamic `pivot (... in (any ...))`, which static
  analysis rejects (dbt0432) because the output columns cannot be known until
  the query runs -- and a model whose column list is unknowable ahead of time
  cannot participate in column lineage or downstream type checking.

  The methods are enumerated instead. There are four, they are already an
  enforced accepted_values test on the staging model, and a fifth would need a
  code change anyway to appear on the finance dashboard.
#}

{% set payment_methods = ['barter', 'coin', 'crystal_transfer', 'guild_credit'] %}

select
    shop_region,

    {% for method in payment_methods %}
    sum(
        case when primary_payment_method = '{{ method }}' then collected_gold else 0 end
    ) as collected_gold_{{ method }},
    {% endfor %}

    sum(collected_gold) as collected_gold_total,
    count(*) as order_count

from {{ ref('fct_orders') }}
where order_status = 'completed'
  and primary_payment_method is not null
group by shop_region
