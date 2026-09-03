with source as (

    select * from {{ ref('raw_orders') }}

),

renamed as (

    select
        order_id,
        customer_id,
        shop_id,
        {{ parse_source_timestamp('ordered_at') }} as ordered_at,
        lower(trim(status)) as order_status,
        lower(trim(channel)) as channel,
        discount_copper,
        {{ copper_to_gold('discount_copper') }} as discount_gold

    from source

)

select * from renamed
