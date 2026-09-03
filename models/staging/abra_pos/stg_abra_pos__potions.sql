with source as (

    select * from {{ ref('raw_potions') }}

),

renamed as (

    select
        potion_sku,
        potion_name,
        lower(trim(category)) as category,
        base_price_copper,
        {{ copper_to_gold('base_price_copper') }} as base_price_gold,
        potency,
        shelf_life_days,
        {{ to_boolean('is_regulated') }} as is_regulated,
        try_to_date(introduced_at) as introduced_at

    from source

)

select * from renamed
