{#
  Merlin & Co. records every price in copper pieces. Reporting is in gold crowns.
  100 copper == 1 gold crown, but the rate lives in a project var so finance can
  re-denominate without a code change.
#}
{% macro copper_to_gold(column_name) %}
    round({{ column_name }} / {{ var('copper_per_gold_crown') }}.0, 2)
{% endmacro %}
