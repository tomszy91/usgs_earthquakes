{% set earthquake_statuses = ["automatic", "reviewed", "deleted"] %}

with source as (
    select
        event_id,
        event_time,
        magnitude,
        depth_km,
        status
    from {{ ref("int_usgs__earthquakes_current")}}
),
aggregation as (
    select
        date(event_time) as event_date,
        round(min(magnitude), 2) as min_magnitude,
        round(max(magnitude), 2) as max_magnitude,
        round(min(depth_km), 2) as min_depth,
        round(max(depth_km), 2) as max_depth,
        {%- for earthquake_status in earthquake_statuses -%}
            sum(case when status = '{{earthquake_status}}' then 1 else 0 end) as status_{{earthquake_status}}_count,
        {%- endfor -%}
        count(*) as total_earthquakes
    from source
    group by event_date
    order by event_date desc
    )
select * from aggregation