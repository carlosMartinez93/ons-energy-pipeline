{{ config(severity='warn') }}

-- Reconciliation: for each month, the sum of the 4 subsystems should match ONS's own
-- national total (SIN row) within 1%. Severity is warn on purpose: the tolerance is an
-- assumption until observed on real data. Any rows returned are months to investigate
-- and to report in the README "Validation" block (max deviation, months affected).

with subsystems as (

    select reference_month, sum(total_generation_gwh) as subsystems_gwh
    from {{ ref('mart_ons__monthly_generation_by_source') }}
    where not is_national_aggregate
    group by 1

),

national as (

    select reference_month, total_generation_gwh as sin_gwh
    from {{ ref('mart_ons__monthly_generation_by_source') }}
    where is_national_aggregate

)

select
    s.reference_month,
    s.subsystems_gwh,
    n.sin_gwh,
    safe_divide(abs(s.subsystems_gwh - n.sin_gwh), n.sin_gwh) as relative_difference

from subsystems as s
inner join national as n
    on s.reference_month = n.reference_month
where safe_divide(abs(s.subsystems_gwh - n.sin_gwh), n.sin_gwh) > 0.01
