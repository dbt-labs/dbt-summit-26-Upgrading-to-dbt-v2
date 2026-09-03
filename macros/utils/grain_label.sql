{#
  Human-readable label for a date_trunc granularity.
#}
{% macro grain_label(granularity) %}
    '{{ granularity }}'
{% endmacro %}
