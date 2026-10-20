with
    source as (select * from {{ source("raw", "raw_earthquakes") }}),
    casted as (
        select
            lower(cast(event_id as string)) as event_id,
            cast(event_time as timestamp) as event_time,
            cast(updated_at as timestamp) as updated_at,
            cast(magnitude as float64) as magnitude,
            lower(cast(place as string)) as place,
            cast(longitude as float64) as longitude,
            cast(latitude as float64) as latitude,
            cast(depth_km as float64) as depth_km,
            lower(cast(status as string)) as status,
            cast(ingested_at as timestamp) as ingested_at,
            lower(cast(raw_json as string)) as raw_json
        from source
    )

select * from casted
