{#
  Messy booleans arrive as Y / N / yes / no / TRUE / FALSE depending on which
  system wrote the row.
#}
{% macro to_boolean(column_name) %}
    case
        when lower(trim({{ column_name }})) in ('y', 'yes', 'true', 't', '1') then true
        when lower(trim({{ column_name }})) in ('n', 'no', 'false', 'f', '0') then false
        else null
    end
{% endmacro %}
