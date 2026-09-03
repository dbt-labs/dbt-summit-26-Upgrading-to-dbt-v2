{#
  Period-over-period change as a fraction.
#}
{% macro pct_change(current_value, previous_value) %}
    round(({{ current_value }} - {{ previous_value }}) / nullif({{ previous_value }}, 0)::float, 4)
{% endmacro %}
