-- Mart: monthly generation by source, per subsystem (and SIN), multi-year.
-- Grain: one row per subsystem_code per reference_month.
-- Unit: GWh. Each hourly reading is in MWmed (average MW over that hour), so
-- sum(MWmed over the hours of the month) = MWh; dividing by 1000 gives GWh.
--
-- SIN rows are kept (is_national_aggregate = true) so the reconciliation test can
-- compare "sum of the 4 subsystems" against ONS's own national total. Consumers that
-- want a national figure should sum the 4 subsystems (is_national_aggregate = false).
--
-- hours_count / hours_with_null_generation expose completeness instead of hiding it:
-- a month with fewer hours than the calendar implies is a partial month.

{{ config(materialized='table') }}

with hourly as (

    select * from {{ ref('stg_ons__balanco_energia_historico') }}

),

monthly as (

    select
        subsystem_code,
        subsystem_name,
        is_national_aggregate,
        date_trunc(date(reading_at), month)                                  as reference_month,

        count(*)                                                             as hours_count,
        countif(
            hydro_generation_mwmed   is null
            or thermal_generation_mwmed is null
            or wind_generation_mwmed    is null
            or solar_generation_mwmed   is null
        )                                                                    as hours_with_null_generation,

        sum(hydro_generation_mwmed)   / 1000                                 as hydro_gwh,
        sum(thermal_generation_mwmed) / 1000                                 as thermal_gwh,
        sum(wind_generation_mwmed)    / 1000                                 as wind_gwh,
        sum(solar_generation_mwmed)   / 1000                                 as solar_gwh,
        sum(load_mwmed)               / 1000                                 as load_gwh

    from hourly
    group by 1, 2, 3, 4

)

select
    *,
    coalesce(hydro_gwh, 0) + coalesce(thermal_gwh, 0)
        + coalesce(wind_gwh, 0) + coalesce(solar_gwh, 0)                     as total_generation_gwh

from monthly
