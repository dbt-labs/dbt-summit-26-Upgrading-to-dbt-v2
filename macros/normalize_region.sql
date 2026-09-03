{#
  The CRM extract codes home_region four different ways -- a two-letter code in
  either case ("NR", "nr") and the full name in either case ("Northern Reaches",
  "northern reaches"). raw_shops.region is canonical, so we conform everything to
  that spelling.
#}
{% macro normalize_region(column_name) %}
    case
        when lower(trim({{ column_name }})) in ('nr', 'northern reaches') then 'Northern Reaches'
        when lower(trim({{ column_name }})) in ('cv', 'crystal vale') then 'Crystal Vale'
        when lower(trim({{ column_name }})) in ('ml', 'the marshlands', 'marshlands') then 'The Marshlands'
        when lower(trim({{ column_name }})) in ('ec', 'ember coast') then 'Ember Coast'
        when lower(trim({{ column_name }})) in ('sw', 'silverwood') then 'Silverwood'
        else null
    end
{% endmacro %}
