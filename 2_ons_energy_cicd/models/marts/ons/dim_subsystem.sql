-- Dimension: ONS subsystems (N, NE, SE, S). Built as a distinct list from
-- staging rather than hardcoded, so it stays in sync with the source.
--
-- This is a shared dimension: both mart_ons__daily_subsystem_balance and
-- mart_ons__hourly_subsystem_balance relate to it via subsystem_code. This
-- lets a single subsystem slicer filter consistently across ALL report
-- pages, even though pages 1-3 use the daily mart and page 4 uses the
-- hourly mart -- without it, a slicer built on either fact table's own
-- subsystem_code column can only ever filter visuals from that same table.

select distinct
    subsystem_code,
    subsystem_name

from {{ ref('stg_ons__balanco_energia_subsistema') }}
where not is_national_aggregate