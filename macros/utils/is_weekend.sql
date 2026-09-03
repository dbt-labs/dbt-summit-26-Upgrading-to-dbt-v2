{#
  True when the timestamp falls on a Saturday or Sunday. Merlin & Co. shops keep
  different hours at weekends, so ops splits most metrics on this.
#}
{% macro is_weekend(timestamp_column) %}
    dayofweek({{ timestamp_column }}) in (0, 6)
{% endmacro %}
