with source as (

    select * from {{ ref('raw_ingredients') }}

),

renamed as (

    select
        ingredient_id,
        ingredient_name,
        supplier_id,
        lower(trim(unit)) as unit,
        unit_cost_copper,
        {{ copper_to_gold('unit_cost_copper') }} as unit_cost_gold,
        {{ to_boolean('is_hazardous') }} as is_hazardous,
        lower(trim(harvest_season)) as harvest_season

    from source

)

select * from renamed
