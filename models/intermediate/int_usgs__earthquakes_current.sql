{{ config(
    materialized='incremental',
    unique_key = 'event_id',
    incremental_strategy = 'merge',
    on_schema_change = 'fail',
    merge_update_columns = ['event_time', 'updated_at', 'magnitude', 'place', 'longitude', 'latitude', 'depth_km', 'status', 'ingested_at', 'raw_json']
)}}

{% if execute and is_incremental() %}
    {% set max_ingested_at_query %}
        select max(ingested_at) as max_ingested_at from {{ this }}
    {% endset %}
    {% set max_ingested_at = run_query(max_ingested_at_query).columns[0].values()[0] %}
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
        {% if is_incremental() %}
        where ingested_at >= timestamp('{{ max_ingested_at }}')
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
        from row_numbered
        where rn = 1
    )
    
select * from deduplicated
