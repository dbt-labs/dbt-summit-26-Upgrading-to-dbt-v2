{#
  Payment activity rolled up to one row per order. Only successful payments
  count toward collected revenue; failures and refunds are tracked separately so
  finance can reconcile.
#}

with payments as (

    select * from {{ ref('stg_abra_pos__payments') }}

),

aggregated as (

    select
        order_id,
        sum(case when payment_status = 'success' then amount_copper else 0 end) as collected_copper,
        sum(case when payment_status = 'refunded' then amount_copper else 0 end) as refunded_copper,
        count(*) as payment_attempt_count,
        count_if(payment_status = 'failed') as failed_payment_count,
        max(paid_at) as last_payment_at,
        min(case when payment_status = 'success' then payment_method end) as primary_payment_method

    from payments
    group by order_id

)

select
    order_id,
    collected_copper,
    {{ copper_to_gold('collected_copper') }} as collected_gold,
    refunded_copper,
    {{ copper_to_gold('refunded_copper') }} as refunded_gold,
    payment_attempt_count,
    failed_payment_count,
    last_payment_at,
    primary_payment_method

from aggregated
