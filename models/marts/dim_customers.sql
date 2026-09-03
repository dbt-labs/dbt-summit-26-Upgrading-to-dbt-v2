{{
    config(
        materialized = 'table'
    )
}}

with customers as (

    select * from {{ ref('stg_grimoire_crm__customers') }}

),

memberships as (

    select * from {{ ref('stg_grimoire_crm__guild_memberships') }}

),

guilds as (

    select * from {{ ref('stg_grimoire_crm__guilds') }}

),

current_membership as (

    select
        memberships.customer_id,
        memberships.guild_id,
        memberships.tier,
        guilds.guild_name,
        memberships.valid_from as tier_since

    from memberships
    inner join guilds
        on memberships.guild_id = guilds.guild_id
    where memberships.is_current_membership

),

order_activity as (

    select
        customer_id,
        count(*) as lifetime_order_count,
        sum(collected_gold) as lifetime_collected_gold,
        min(ordered_at) as first_order_at,
        max(ordered_at) as most_recent_order_at

    from {{ ref('fct_orders') }}
    where order_status = 'completed'
    group by customer_id

),

final as (

    select
        customers.customer_id,
        customers.full_name,
        customers.email,
        customers.home_region,
        customers.signed_up_at,
        customers.birth_year,
        customers.favored_discipline,

        current_membership.guild_id,
        current_membership.guild_name,
        current_membership.tier as guild_tier,
        current_membership.tier_since as guild_tier_since,

        coalesce(order_activity.lifetime_order_count, 0) as lifetime_order_count,
        coalesce(order_activity.lifetime_collected_gold, 0) as lifetime_collected_gold,
        order_activity.first_order_at,
        order_activity.most_recent_order_at,

        case
            when order_activity.lifetime_collected_gold >= 500 then 'archmage'
            when order_activity.lifetime_collected_gold >= 150 then 'adept'
            when order_activity.lifetime_collected_gold > 0 then 'apprentice'
            else 'prospect'
        end as value_segment,

        {{ audit_columns() }}

    from customers
    left join current_membership
        on customers.customer_id = current_membership.customer_id
    left join order_activity
        on customers.customer_id = order_activity.customer_id

)

select * from final
