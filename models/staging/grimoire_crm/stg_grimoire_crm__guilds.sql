with source as (

    select * from {{ ref('raw_guilds') }}

),

renamed as (

    select
        guild_id,
        guild_name,
        founded_year

    from source

)

select * from renamed
