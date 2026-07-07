-- Intermediate: aligns CMO (half-hourly) to the energy balance grain (hourly)
-- by averaging the two half-hour readings within each hour, then joins
-- generation/load with marginal cost per subsystem/hour.
--
-- National aggregate rows (SIN) are excluded here on purpose: CMO has no
-- equivalent national row, so a join would just produce nulls for SIN.
-- Use stg_ons__balanco_energia_subsistema directly (with is_national_aggregate)
-- for "Brazil total" KPIs that don't need cost.

with energy_balance as (

    select *
    from {{ ref('stg_ons__balanco_energia_subsistema') }}
    where not is_national_aggregate

),

cmo_hourly as (

    select
        subsystem_code,
        timestamp_trunc(reading_at, hour) as reading_hour,
        avg(marginal_cost_per_mwh)       as marginal_cost_per_mwh

    from {{ ref('stg_ons__cmo_semi_horario') }}
    group by 1, 2

),

joined as (

    select
        eb.subsystem_code,
        eb.subsystem_name,
        eb.reading_at,

        eb.hydro_generation_mwmed,
        eb.thermal_generation_mwmed,
        eb.wind_generation_mwmed,
        eb.solar_generation_mwmed,
        eb.load_mwmed,
        eb.interchange_mwmed,

        cmo.marginal_cost_per_mwh

    from energy_balance as eb
    left join cmo_hourly as cmo
        on eb.subsystem_code = cmo.subsystem_code
        and eb.reading_at = cmo.reading_hour

)

select * from joined
