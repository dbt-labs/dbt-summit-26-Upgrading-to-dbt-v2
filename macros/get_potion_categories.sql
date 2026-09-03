{#
  Builds one pivoted revenue column per potion category so the marts layer does
  not have to be edited every time merchandising adds a category.

  The category list is read straight out of the warehouse at compile time. Two
  guards are needed for that to be safe:
    * `execute` -- during parsing there is no connection at all.
    * `load_relation` -- on a cold start the staging table does not exist yet,
      so fall back to the categories we know shipped with the catalogue.
#}
{% macro get_potion_categories() %}

    {% set fallback_categories = ['clarity', 'healing', 'invisibility', 'love', 'luck', 'strength'] %}

    {% if not execute %}
        {{ return([]) }}
    {% endif %}

    {% set potions_relation = ref('stg_abra_pos__potions') %}

    {% if load_relation(potions_relation) is none %}
        {{ return(fallback_categories) }}
    {% endif %}

    {% set category_query %}
        select distinct lower(trim(category)) as category
        from {{ potions_relation }}
        order by 1
    {% endset %}

    {% set results = run_query(category_query) %}
    {% set categories = results.columns[0].values() %}

    {{ return(categories if categories | length > 0 else fallback_categories) }}

{% endmacro %}
