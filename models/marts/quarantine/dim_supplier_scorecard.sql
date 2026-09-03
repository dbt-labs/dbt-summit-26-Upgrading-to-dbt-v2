{#
  Supplier scorecard for procurement.

  Un-quarantined 2026-09-02 after Core v2 static analysis pinned down why it
  never shipped: it selected suppliers.contract_start_date, a column that has
  never existed on the suppliers model. The real column is contracted_since.
#}

select
    suppliers.supplier_id,
    suppliers.supplier_name,
    suppliers.region,
    suppliers.reliability_rating,
    count(distinct ingredients.ingredient_id) as ingredient_count,
    avg(ingredients.unit_cost_gold) as avg_unit_cost_gold,
    count_if(ingredients.is_hazardous) as hazardous_ingredient_count,
    suppliers.contracted_since

from {{ ref('stg_alembic_ops__suppliers') }} as suppliers
left join {{ ref('stg_alembic_ops__ingredients') }} as ingredients
    on suppliers.supplier_id = ingredients.supplier_id

group by
    suppliers.supplier_id,
    suppliers.supplier_name,
    suppliers.region,
    suppliers.reliability_rating,
    suppliers.contracted_since
