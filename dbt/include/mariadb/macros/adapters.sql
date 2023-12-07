{# core/dbt/include/global_project/macros/utils/data_types.sql #}
{%- macro mariadb__type_string() -%}
{{- log("mariadb__type_string", info=True) }}
varchar
{%- endmacro -%}

{%- macro mariadb__type_numeric() -%}
decimal
{%- endmacro -%}

{%- macro mariadb__hash(field) -%}
    md5(cast({{ field }} as char))
{%- endmacro -%}

{% macro mariadb__current_timestamp() -%}
  current_timestamp 
{%- endmacro %}

{# core/dbt/include/global_project/macros/adapters/indexes.sql #}
{% macro mariadb__get_create_index_sql(relation, index_dict) -%}
{% set sql %}
    CREATE INDEX {{ relation.identifier }}_{{ index_dict.columns | join('_') }} USING BTREE ON {{ relation }} ({{ index_dict.columns | join(', ') }});
{% endset %}
{% do return(sql) %}
{% endmacro %}

{# core/dbt/include/global_project/macros/relations/drop.sql #}
{%- macro mariadb__get_drop_sql(relation) -%}

    {{ log("mariadb__get_drop_sql: " ~ relation, info=True) }}

    {%- if relation.is_view -%}
        {{ drop_view(relation) }}

    {%- elif relation.is_table -%}
        {{ drop_table(relation) }}

    {%- elif relation.is_materialized_view -%}
        {{ drop_materialized_view(relation) }}

    {%- else -%}
        drop {{ relation.type }} if exists {{ relation }} cascade

    {%- endif -%}

{%- endmacro -%}

{# core/dbt/include/global_project/macros/adapters/persist_docs.sql #}
{% macro mariadb__alter_column_comment(relation, column_dict) -%}
  {{ exceptions.raise_not_implemented(
    'alter_column_comment macro not implemented for adapter '+adapter.type()) }}
{% endmacro %}

{% macro mariadb__alter_relation_comment(relation, relation_comment) -%}
  {%- set sql %}
      ALTER TABLE {{ relation.identifier }}
      COMMENT {{ relation_comment }}
  ;
  {%- endset %}
  {%- do return(sql) -%}
{% endmacro %}

{# information schema related #}
{# core/dbt/include/global_project/macros/adapters/metadata.sql #}
{% macro mariadb__information_schema_name(database) -%}
  {{- log("information_schema_name:   database_name: " ~ database_name ~ "  database: " ~ database, info=True) -}}
  information_schema
{%- endmacro %}

{# dbt/include/mariadb/macros/adapters.sql #}
{% macro mariadb__list_schemas(database) %}
  {{- log("list_schemas:   database_name: " ~ database_name ~ "  database: " ~ database, info=True) -}}
  {% call statement('list_schemas', fetch_result=True, auto_begin=False) -%}
    select distinct schema_name
    from {{ information_schema_name(database) }}.schemata
  {%- endcall %}

  {{ return(load_result('list_schemas').table) }}
{% endmacro %}

{% macro mariadb__create_schema(relation) -%}
  {%- call statement('create_schema') -%}
    create schema if not exists {{ relation.without_identifier() }}
  {%- endcall -%}
{% endmacro %}

{% macro mariadb__drop_schema(relation) -%}
  {%- call statement('drop_schema') -%}
    drop schema if exists {{ relation.without_identifier() }}
  {% endcall %}
{% endmacro %}

{% macro mariadb__drop_relation(relation) -%}
    {% call statement('drop_relation', auto_begin=False) -%}
        drop {{ relation.type }} if exists {{ relation }}
    {%- endcall %}
{% endmacro %}

{% macro mariadb__truncate_relation(relation) -%}
    {% call statement('truncate_relation') -%}
      truncate table {{ relation }}
    {%- endcall %}
{% endmacro %}

{% macro mariadb__create_table_as(temporary, relation, sql) -%}
  {%- set sql_header = config.get('sql_header', none) -%}

  {{ sql_header if sql_header is not none }}

  create {% if temporary: -%}temporary{%- endif %} table
    {{ relation.include(database=False) }}
    {{ sql }}
{% endmacro %}

{% macro mariadb__create_view_as(relation, sql) -%}
  {%- set sql_header = config.get('sql_header', none) -%}

  {{ sql_header if sql_header is not none }}
  create view {{ relation }} as
    {{ sql }}
{%- endmacro %}

{% macro mariadb__current_timestamp() -%}
  current_timestamp()
{%- endmacro %}

{% macro mariadb__rename_relation(from_relation, to_relation) -%}
  {#
    Rename fails when the relation already exists, so a 2-step process is needed:
    1. Drop the existing relation
    2. Rename the new relation to existing relation
  #}
  {% call statement('drop_relation') %}
    drop {{ to_relation.type }} if exists {{ to_relation }} cascade
  {% endcall %}
  {% call statement('rename_relation') %}
    rename table {{ from_relation }} to {{ to_relation }}
  {% endcall %}
{% endmacro %}

{% macro mariadb__check_schema_exists(database, schema) -%}
    {# no-op #}
    {# see MariaDBAdapter.check_schema_exists() #}
{% endmacro %}

{% macro mariadb__get_columns_in_relation(relation) -%}
    {% call statement('get_columns_in_relation', fetch_result=True) %}
        show columns from {{ relation.schema }}.{{ relation.identifier }}
    {% endcall %}

    {% set table = load_result('get_columns_in_relation').table %}
    {{ return(sql_convert_columns_in_relation(table)) }}
{% endmacro %}

{% macro mariadb__list_relations_without_caching(schema_relation) %}
  {% call statement('list_relations_without_caching', fetch_result=True) -%}
    select
      null as "database",
      table_name as name,
      table_schema as "schema",
      case when table_type = 'BASE TABLE' then 'table'
           when table_type = 'VIEW' then 'view'
           else table_type
      end as table_type
    from information_schema.tables
    where table_schema = '{{ schema_relation.schema }}'
  {% endcall %}
  {{ return(load_result('list_relations_without_caching').table) }}
{% endmacro %}

{% macro mariadb__generate_database_name(custom_database_name=none, node=none) -%}
  {% do return(None) %}
{%- endmacro %}
