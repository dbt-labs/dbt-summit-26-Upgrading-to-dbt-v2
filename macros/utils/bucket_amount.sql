{#
  Buckets a gold-crown amount into the bands the loyalty program uses.
#}
{% macro bucket_amount(column_name, low_threshold, high_threshold) %}
    case
        when {{ column_name }} >= {{ high_threshold }} then 'high'
        when {{ column_name }} >= {{ low_threshold }} then 'medium'
        when {{ column_name }} > 0 then 'low'
        else 'none'
    end
{% endmacro %}
