{#
  QUARANTINED 2026-01-29.

  Procurement asked for a supplier scorecard, then re-scoped the request before
  this shipped. Left in the repo, switched off, in case they come back to it.

  Re-enable with:  --vars 'include_quarantined: true'
#}

select
    suppliers.supplier_id,
    suppliers.supplier_name,
    suppliers.region,
    suppliers.reliability_rating,
    count(distinct ingredients.ingredient_id) as ingredient_count,
    avg(ingredients.unit_cost_gold) as avg_unit_cost_gold,
    count_if(ingredients.is_hazardous) as hazardous_ingredient_count,
    suppliers.contract_start_date

from {{ ref('stg_alembic_ops__suppliers') }} as suppliers
left join {{ ref('stg_alembic_ops__ingredients') }} as ingredients
    on suppliers.supplier_id = ingredients.supplier_id

group by
    suppliers.supplier_id,
    suppliers.supplier_name,
    suppliers.region,
    suppliers.reliability_rating,
    suppliers.contract_start_date
