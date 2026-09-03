{#
  Payment attempts, built incrementally -- the payments feed is append-mostly and
  large enough that a full rebuild every night is wasteful.

  unique_key is what keeps the reload window idempotent: the window below
  re-reads the boundary period on purpose, since a payment can land with a
  paid_at slightly behind the previous high-water mark.
#}

{{ config(
    materialized='incremental', 
    incremental_strategy='merge', 
    meta={'unique_keys': 'payment_id'}
) }}

select
    payment_id,
    order_id,
    payment_method,
    payment_status,
    amount_copper,
    amount_gold,
    paid_at

from {{ ref('stg_abra_pos__payments') }}

{% if is_incremental() %}
where paid_at >= (select max(paid_at) from {{ this }})
{% endif %}
