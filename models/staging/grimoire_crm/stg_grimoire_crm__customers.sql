with source as (

    select * from {{ ref('raw_customers') }}

),

renamed as (

    select
        customer_id,
        full_name,
        nullif(trim(email), '') as email,
        {{ normalize_region('home_region') }} as home_region,
        try_to_date(signed_up_at) as signed_up_at,
        birth_year,
        lower(trim(favored_discipline)) as favored_discipline

    from source

)

select * from renamed
