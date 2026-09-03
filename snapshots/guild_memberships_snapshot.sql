{#
  Guild tiers change over time and the CRM overwrites them in place, so we
  snapshot the current membership rows to keep our own history.
#}

{% snapshot guild_memberships_snapshot %}

{{
    config(
        target_schema = 'dbt_workshop_MTesting_ba1c70',
        unique_key = 'membership_id',
        strategy = 'check',
        check_cols = ['tier', 'guild_id', 'valid_to'],
        invalidate_hard_deletes = True
    )
}}

select
    membership_id,
    customer_id,
    guild_id,
    tier,
    valid_from,
    valid_to,
    is_current_membership

from {{ ref('stg_grimoire_crm__guild_memberships') }}

{% endsnapshot %}
