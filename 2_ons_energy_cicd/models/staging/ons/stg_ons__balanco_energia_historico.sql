-- Staging: ONS energy balance, MULTI-YEAR table (raw_ons.balanco_energia_subsistema_historico).
-- Same renaming/typing as stg_ons__balanco_energia_subsistema (2024 only, feeds the CMO mart).
-- Kept as a separate model on purpose: adding years to the original table would make the
-- cost mart join against a CMO source that only has 2024 and would break test_cmo_no_new_gaps.
-- SIN rows are kept and flagged (is_national_aggregate); consumers decide whether to use them.

with source as (

    select * from {{ source('raw_ons', 'balanco_energia_subsistema_historico') }}

),

renamed as (

    select
        trim(id_subsistema)                    as subsystem_code,
        trim(nom_subsistema)                   as subsystem_name,
        din_instante                           as reading_at,
        (trim(id_subsistema) = 'SIN')          as is_national_aggregate,

        val_gerhidraulica                      as hydro_generation_mwmed,
        val_gertermica                         as thermal_generation_mwmed,
        val_gereolica                          as wind_generation_mwmed,
        val_gersolar                           as solar_generation_mwmed,
        val_carga                              as load_mwmed,
        val_intercambio                        as interchange_mwmed

    from source

)

select * from renamed
