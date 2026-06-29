with
    source as (select * from {{ source("raw", "raw_earthquakes") }}),
    casted as (
        select
            cast(event_id as string) as event_id,
            cast(event_time as timestamp) as event_time,
            cast(updated_at as timestamp) as updated_at,
            cast(magnitude as float64) as magnitude,
            cast(place as string) as place,
            cast(longitude as float64) as longitude,
            cast(latitude as float64) as latitude,
            cast(depth_km as float64) as depth_km,
            cast(status as string) as status,
            cast(ingested_at as timestamp) as ingested_at,
            cast(raw_json as string) as raw_json
        from source
    )

select * from casted
