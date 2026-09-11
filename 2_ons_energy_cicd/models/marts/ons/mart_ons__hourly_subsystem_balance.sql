-- Mart: hourly energy balance and cost by subsystem, exposed for BI consumption.
-- Grain: one row per subsystem per hour (finest grain available).
-- Used specifically for the "Seasonal Patterns" report page (hour x weekday
-- heatmaps) -- the daily mart is too coarse for that view.

select
    subsystem_code,
    subsystem_name,
    reading_at,

    extract(hour from reading_at) as hour_of_day,
    format_timestamp('%A', reading_at) as weekday_name,
    extract(dayofweek from reading_at) as weekday_number,  -- 1=Sunday .. 7=Saturday (BigQuery default)

    hydro_generation_mwmed,
    thermal_generation_mwmed,
    wind_generation_mwmed,
    solar_generation_mwmed,
    load_mwmed,
    interchange_mwmed,
    marginal_cost_per_mwh,

    hydro_generation_mwmed + thermal_generation_mwmed
        + wind_generation_mwmed + solar_generation_mwmed as total_generation_mwmed

from {{ ref('int_ons__energy_balance_with_cost') }}