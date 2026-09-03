with source as (

    select * from {{ ref('raw_suppliers') }}

),

renamed as (

    select
        supplier_id,
        supplier_name,
        region,
        reliability_rating,
        try_to_date(contracted_since) as contracted_since

    from source

)

select * from renamed
