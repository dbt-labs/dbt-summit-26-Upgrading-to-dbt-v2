select
    brew_id,
    brew_events.potion_sku as potion_sku,
    shop_id,
    cauldron_id,
    brewed_at,
    batch_size,
    brew_duration_minutes,
    quality_check,
    batch_size / nullif(brew_duration_minutes, 0) as units_per_minute

from {{ ref('stg_alembic_ops__brew_events') }} as brew_events
join {{ ref('stg_abra_pos__potions') }} as potions
    on brew_events.potion_sku = potions.potion_sku
