with source as (

    select * from {{ ref('raw_guild_memberships') }}

),

renamed as (

    select
        membership_id,
        customer_id,
        guild_id,
        lower(trim(tier)) as tier,
        try_to_date(valid_from) as valid_from,
        try_to_date(nullif(trim(valid_to), '')) as valid_to,
        nullif(trim(valid_to), '') is null as is_current_membership

    from source

)

select * from renamed
