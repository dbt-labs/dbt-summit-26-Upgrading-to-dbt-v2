with source as (

    select * from {{ source('grimoire_crm', 'raw_guilds') }}

),

renamed as (

    select
        guild_id,
        guild_name,
        founded_year

    from source

)

select * from renamed
