{#
  Small dimension -- 120 potions -- so this is a view rather than a table. No
  point paying for storage and a rebuild on something this size.
#}

{{
    config(
        materialized = 'view'
    )
}}

with potions as (

    select * from {{ ref('stg_abra_pos__potions') }}

),

recipe_cost as (

    select
        potion_ingredients.potion_sku,
        count(*) as ingredient_count,
        sum(potion_ingredients.quantity * ingredients.unit_cost_copper) as recipe_cost_copper,
        max(case when ingredients.is_hazardous then 1 else 0 end) = 1 as has_hazardous_ingredient

    from {{ ref('stg_alembic_ops__potion_ingredients') }} as potion_ingredients
    inner join {{ ref('stg_alembic_ops__ingredients') }} as ingredients
        on potion_ingredients.ingredient_id = ingredients.ingredient_id
    group by potion_ingredients.potion_sku

),

brew_stats as (

    select
        potion_sku,
        count(*) as brew_event_count,
        sum(batch_size) as total_units_brewed,
        avg(brew_duration_minutes) as avg_brew_duration_minutes,
        {{ safe_divide("count_if(quality_check = 'fail')", "count(*)::float") }} as brew_failure_rate

    from {{ ref('stg_alembic_ops__brew_events') }}
    group by potion_sku

),

final as (

    select
        potions.potion_sku,
        potions.potion_name,
        potions.category,
        potions.potency,
        potions.shelf_life_days,
        potions.is_regulated,
        potions.introduced_at,
        potions.base_price_copper,
        potions.base_price_gold,

        recipe_cost.ingredient_count,
        recipe_cost.recipe_cost_copper,
        {{ copper_to_gold('recipe_cost.recipe_cost_copper') }} as recipe_cost_gold,
        recipe_cost.has_hazardous_ingredient,

        potions.base_price_copper - recipe_cost.recipe_cost_copper as unit_margin_copper,
        round(
            (potions.base_price_copper - recipe_cost.recipe_cost_copper)
            / nullif(potions.base_price_copper, 0)::float,
            4
        ) as unit_margin_pct,

        brew_stats.brew_event_count,
        brew_stats.total_units_brewed,
        brew_stats.avg_brew_duration_minutes,
        brew_stats.brew_failure_rate,

        {{ audit_columns() }}

    from potions
    left join recipe_cost
        on potions.potion_sku = recipe_cost.potion_sku
    left join brew_stats
        on potions.potion_sku = brew_stats.potion_sku

)

select * from final
