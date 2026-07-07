-- Staging: ONS energy balance (load + generation by source, hourly, per subsystem).
-- Only renaming and type casting here, no business logic.
-- "SIN" rows are kept (not filtered) but flagged, since they're a pre-computed
-- national total, not a fifth subsystem -- consumers must decide whether to
-- include or exclude them depending on the analysis (e.g. exclude SIN when
-- summing generation by subsystem, use SIN directly for "Brazil total" KPIs).

with source as (

    select * from {{ source('raw_ons', 'balanco_energia_subsistema') }}

),

renamed as (

    select
        id_subsistema                          as subsystem_code,
        nom_subsistema                         as subsystem_name,
        din_instante                           as reading_at,
        (id_subsistema = 'SIN')                as is_national_aggregate,

        val_gerhidraulica                      as hydro_generation_mwmed,
        val_gertermica                         as thermal_generation_mwmed,
        val_gereolica                          as wind_generation_mwmed,
        val_gersolar                           as solar_generation_mwmed,
        val_carga                              as load_mwmed,
        val_intercambio                        as interchange_mwmed

    from source

)

select * from renamed