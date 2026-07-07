-- Staging: ONS Marginal Operation Cost (CMO), half-hourly, per subsystem.
-- Only renaming and type casting here. Hourly aggregation (to join with the
-- energy balance, which is hourly) happens downstream in an intermediate model.

with source as (

    select * from {{ source('raw_ons', 'cmo_semi_horario') }}

),

renamed as (

    select
        id_subsistema       as subsystem_code,
        nom_subsistema      as subsystem_name,
        din_instante        as reading_at,
        val_cmo             as marginal_cost_per_mwh

    from source

)

select * from renamed