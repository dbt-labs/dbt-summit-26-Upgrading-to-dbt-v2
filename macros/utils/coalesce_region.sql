{#
  Prefers the canonical shop region, falling back to the customer's own coding.
#}
{% macro coalesce_region(shop_region, customer_region, fallback_label="'unknown'") %}
    coalesce({{ shop_region }}, {{ customer_region }}, {{ fallback_label }})
{% endmacro %}
