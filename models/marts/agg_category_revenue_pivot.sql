{{
    config(
        materialized = 'table'
    )
}}

{#
  One revenue column per potion category, pivoted so the merchandising dashboard
  can read it without a crosstab step.

  The category list is discovered from the warehouse at compile time by
  get_potion_categories(), so merchandising can add a category without anybody
  editing this model.
#}

{#
  get_potion_categories() reaches for stg_abra_pos__potions inside a conditional,
  so dbt cannot infer the edge on its own. Declare it explicitly.
#}
-- depends_on: {{ ref('stg_abra_pos__potions') }}

{% set categories = get_potion_categories() %}

with order_items as (

    select * from {{ ref('fct_order_items') }}

),

pivoted as (

    select
        shop_region,
        date_trunc('month', ordered_at) as order_month,

        {% for category in categories %}
        sum(
            case
                when potion_category = '{{ category }}'
                then gross_line_amount_gold
                else 0
            end
        ) as revenue_{{ category | replace(' ', '_') }}_gold
        {%- if not loop.last %},{% endif %}
        {% endfor %}

        {% if categories | length > 0 %},{% endif %}
        sum(gross_line_amount_gold) as revenue_total_gold,
        count(distinct order_id) as order_count

    from order_items
    where order_status = 'completed'
    group by shop_region, date_trunc('month', ordered_at)

)

select * from pivoted
