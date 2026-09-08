with source as (

    select * from {{ source('alembic_ops', 'raw_potion_ingredients') }}

),

renamed as (

    select
        potion_sku,
        ingredient_id,
        quantity,
        lower(trim(unit)) as unit

    from source

)

select * from renamed
