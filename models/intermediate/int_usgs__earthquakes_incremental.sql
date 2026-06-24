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
        from {{ ref("stg_usgs__earthquakes") }}),
    
    deduplicated as (
        select
            *,
            row_number() over (partition by event_id order by ingested_at desc) as rn
        from source
        where rn = 1
    )
    
select * from deduplicated
