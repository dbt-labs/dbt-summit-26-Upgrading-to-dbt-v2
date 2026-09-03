{#
  Division that yields null rather than erroring when the denominator is zero.
#}
{% macro safe_divide(numerator, denominator, default_value='null') %}
    coalesce({{ numerator }} / nullif({{ denominator }}, 0), {{ default_value }})
{% endmacro %}
