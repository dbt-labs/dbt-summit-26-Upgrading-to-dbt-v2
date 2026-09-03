with source as (

    select * from {{ ref('raw_payments') }}

),

renamed as (

    select
        payment_id,
        order_id,
        lower(trim(method)) as payment_method,
        lower(trim(status)) as payment_status,
        amount_copper,
        {{ copper_to_gold('amount_copper') }} as amount_gold,
        {{ parse_source_timestamp('paid_at') }} as paid_at

    from source

)

select * from renamed
