-- Mart: daily energy balance and cost by subsystem, ready for BI consumption.
-- Grain: one row per subsystem per day.
-- This is where hourly data gets rolled up -- Power BI should read from here,
-- not from the intermediate model, to keep report-level DAX simple and fast.

with hourly as (

    select * from {{ ref('int_ons__energy_balance_with_cost') }}

),

daily as (

    select
        subsystem_code,
        subsystem_name,
        date(reading_at)                                   as reading_date,

        -- generation totals (MWmed averaged across the day's hours)
        avg(hydro_generation_mwmed)                        as avg_hydro_generation_mwmed,
        avg(thermal_generation_mwmed)                       as avg_thermal_generation_mwmed,
        avg(wind_generation_mwmed)                          as avg_wind_generation_mwmed,
        avg(solar_generation_mwmed)                         as avg_solar_generation_mwmed,
        avg(load_mwmed)                                     as avg_load_mwmed,
        avg(interchange_mwmed)                              as avg_interchange_mwmed,

        -- cost: daily average and peak (worst hour) marginal cost
        avg(marginal_cost_per_mwh)                          as avg_marginal_cost_per_mwh,
        max(marginal_cost_per_mwh)                          as max_marginal_cost_per_mwh,

        -- data quality signal: how many of the day's 24 hours have a cost reading
        -- (relevant given the known CMO completeness gap)
        count(marginal_cost_per_mwh)                        as hours_with_cost_data,
        count(*)                                            as hours_total

    from hourly
    group by 1, 2, 3

),

with_generation_mix as (

    select
        *,
        avg_hydro_generation_mwmed + avg_thermal_generation_mwmed
            + avg_wind_generation_mwmed + avg_solar_generation_mwmed as total_generation_mwmed,

        safe_divide(
            avg_hydro_generation_mwmed,
            avg_hydro_generation_mwmed + avg_thermal_generation_mwmed
                + avg_wind_generation_mwmed + avg_solar_generation_mwmed
        )                                                              as hydro_share,

        safe_divide(
            avg_thermal_generation_mwmed,
            avg_hydro_generation_mwmed + avg_thermal_generation_mwmed
                + avg_wind_generation_mwmed + avg_solar_generation_mwmed
        )                                                              as thermal_share,

        safe_divide(
            avg_wind_generation_mwmed,
            avg_hydro_generation_mwmed + avg_thermal_generation_mwmed
                + avg_wind_generation_mwmed + avg_solar_generation_mwmed
        )                                                              as wind_share,

        safe_divide(
            avg_solar_generation_mwmed,
            avg_hydro_generation_mwmed + avg_thermal_generation_mwmed
                + avg_wind_generation_mwmed + avg_solar_generation_mwmed
        )                                                              as solar_share

    from daily

)

select * from with_generation_mix
