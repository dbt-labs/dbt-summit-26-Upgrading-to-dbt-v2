with source as (

    select * from {{ ref('raw_order_items') }}

),

renamed as (

    select
        order_item_id,
        order_id,
        potion_sku,
        quantity,
        unit_price_copper,
        {{ copper_to_gold('unit_price_copper') }} as unit_price_gold,
        quantity * unit_price_copper as gross_line_amount_copper,
        {{ copper_to_gold('quantity * unit_price_copper') }} as gross_line_amount_gold

    from source

)

select * from renamed
