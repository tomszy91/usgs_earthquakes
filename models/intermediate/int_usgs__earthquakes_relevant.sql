{{ config(
    materialized='view'
) }}

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
    ),
    
    filtered as (
        select
            *
        from source
        where event_time >= timestamp('{{ var("project_start") }}')
    )

select * from filtered
