{#
  Upstream systems emit two timestamp shapes in the same column: ISO-8601 with a
  trailing Z, and a space-separated local form. Snowflake's auto-detection
  handles both, so we lean on try_to_timestamp_ntz to avoid dropping rows.
#}
{% macro parse_source_timestamp(column_name) %}
    try_to_timestamp_ntz(replace(replace({{ column_name }}, 'T', ' '), 'Z', ''))
{% endmacro %}
