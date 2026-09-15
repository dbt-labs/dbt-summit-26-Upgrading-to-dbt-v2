{#
  True when the timestamp falls on a Saturday or Sunday. Merlin & Co. shops keep
  different hours at weekends, so ops splits most metrics on this.
#}
{% macro is_weekend(timestamp_column) %}
    dayofweekiso({{ timestamp_column }}) in (6, 7)
{% endmacro %}
