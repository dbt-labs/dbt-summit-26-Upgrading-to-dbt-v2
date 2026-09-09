{#
  QUARANTINED 2026-02-04.

  Ops wanted brew yield per cauldron. Shelved when the cauldron dimension never
  materialized -- cauldron_id is still just a bare string on the brew events.

  Re-enable with:  --vars 'include_quarantined: true'
#}

select
    brew_events.brew_id,
    brew_events.potion_sku,
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
