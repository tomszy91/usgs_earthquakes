select
    event_id,
    event_time,
    ingested_at
from {{ ref("int_usgs__earthquakes_current") }}
where timestamp(event_time) < timestamp('{{ var("project_start") }}')