{{ config(
    materialized='incremental',
    unique_key = 'event_id',
    incremental_strategy = 'merge',
    on_schema_change = 'fail',
    merge_update_columns = ['event_time', 'updated_at', 'magnitude', 'place', 'longitude', 'latitude', 'depth_km', 'status', 'ingested_at', 'raw_json']
)}}

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
        from {{ ref("int_usgs__earthquakes_deduplicate") }})
        {% if is_incremental() %}
            where ingested_at >= (select max(ingested_at) from {{ this }})
        {% endif %}    

select * from source