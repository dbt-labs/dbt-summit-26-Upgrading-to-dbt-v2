{#
  Merlin & Co. keeps a house materialization for regulator-facing tables: build
  the relation, then stamp a row into the audit ledger so Compliance can prove
  when each table was last rebuilt.

  Static analysis cannot follow the ledger insert, so models using this
  materialization are opted out of it in dbt_project.yml.
#}

{% materialization audit_table, default %}

    {%- set target_relation = this.incorporate(type='table') -%}

    {{ run_hooks(pre_hooks, inside_transaction=False) }}
    {{ run_hooks(pre_hooks, inside_transaction=True) }}

    {%- call statement('main') -%}
        {{ create_table_as(False, target_relation, sql) }}
    {%- endcall -%}

    {%- set ledger_relation = api.Relation.create(
        database = target_relation.database,
        schema   = target_relation.schema,
        identifier = 'merlinco_build_ledger'
    ) -%}

    {%- call statement('create_ledger') -%}
        create table if not exists {{ ledger_relation }} (
            relation_name varchar,
            built_at timestamp_ntz,
            invocation_id varchar,
            row_count number
        )
    {%- endcall -%}

    {%- call statement('write_ledger') -%}
        insert into {{ ledger_relation }} (relation_name, built_at, invocation_id, row_count)
        select
            '{{ target_relation }}',
            current_timestamp()::timestamp_ntz,
            '{{ invocation_id }}',
            count(*)
        from {{ target_relation }}
    {%- endcall -%}

    {{ run_hooks(post_hooks, inside_transaction=True) }}
    {{ adapter.commit() }}
    {{ run_hooks(post_hooks, inside_transaction=False) }}

    {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}
