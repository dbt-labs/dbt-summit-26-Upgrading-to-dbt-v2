{#
  Brew yield per batch.

  Un-quarantined 2026-09-02. Every column reference is now qualified -- the
  model previously selected a bare potion_sku, which is ambiguous because both
  sides of the join carry it.
#}

select
    brew_events.brew_id,
    brew_events.potion_sku,
    potions.potion_name,
    brew_events.shop_id,
    brew_events.cauldron_id,
    brew_events.brewed_at,
    brew_events.batch_size,
    brew_events.brew_duration_minutes,
    brew_events.quality_check,
    brew_events.batch_size / nullif(brew_events.brew_duration_minutes, 0) as units_per_minute

from {{ ref('stg_alembic_ops__brew_events') }} as brew_events
join {{ ref('stg_abra_pos__potions') }} as potions
    on brew_events.potion_sku = potions.potion_sku
