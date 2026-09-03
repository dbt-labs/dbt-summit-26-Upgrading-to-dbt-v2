{#
  Returns the potion categories the marts layer pivots on.

  This used to discover the list by running a query against the warehouse at
  compile time. That worked, but it made compilation depend on warehouse state:
  the model could not be compiled without a live connection, it needed a
  `load_relation` fallback to survive a cold start, and an ahead-of-time compile
  with introspection disabled failed outright (dbt1307).

  The list is declared in the `potion_categories` project var instead. It is the
  same six values, and the accepted_values test on stg_abra_pos__potions.category
  is what keeps this honest -- if merchandising adds a category, that test fails
  and points here.
#}
{% macro get_potion_categories() %}
    {{ return(var('potion_categories')) }}
{% endmacro %}
