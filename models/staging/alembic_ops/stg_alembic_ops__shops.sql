with source as (

    select * from {{ ref('raw_shops') }}

),

renamed as (

    select
        shop_id,
        shop_name,
        city,
        region,
        try_to_date(opened_at) as opened_at

    from source

)

select * from renamed
