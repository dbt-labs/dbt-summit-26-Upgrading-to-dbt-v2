with source as (

    select * from {{ ref('raw_brew_events') }}

),

renamed as (

    select
        brew_id,
        potion_sku,
        shop_id,
        cauldron_id,
        {{ parse_source_timestamp('brewed_at') }} as brewed_at,
        batch_size,
        brew_duration_minutes,
        lower(trim(quality_check)) as quality_check,
        brewer_name

    from source

)

select * from renamed
