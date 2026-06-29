{{ config(
    materialized='incremental',
    unique_key = 'event_id',
    incremental_strategy = 'merge',
    on_schema_change = 'fail',
    merge_update_columns = ['event_time', 'updated_at', 'magnitude', 'place', 'longitude', 'latitude', 'depth_km', 'status', 'ingested_at', 'raw_json']
) }}

{% if execute and is_incremental() %}
    {% set max_ingested_at_query %}
        select max(ingested_at) from {{ this }}
    {% endset %}

    {% set max_ingested_at = dbt_utils.get_single_value(max_ingested_at_query) %}

{% endif %}

with    
    source as (
        select
            event_id,
            event_time,
            updated_at,
            magnitude,
            place,
            longitude,
            latitude,
            depth_km,
            status,
            ingested_at,
            raw_json
        from {{ ref("stg_usgs__earthquakes") }}
        where event_time >= timestamp('{{ var("project_start") }}')

        {% if is_incremental() %}
            and ingested_at >= timestamp('{{ max_ingested_at }}')
        {% endif %}    
    ),
    
    row_numbered as (
        select
            *,
            row_number() over (partition by event_id order by ingested_at desc) as rn
        from source
    ),

    deduplicated as (
        select
            * except (rn)
        from row_numbered
        where rn = 1
    )

select * from deduplicated
