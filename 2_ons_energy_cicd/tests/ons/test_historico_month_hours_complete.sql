{{ config(severity='warn') }}

-- Completeness: a full month has days*24 hourly readings per subsystem. Tolerance of +-1
-- hour absorbs daylight-saving shifts present in older years (assumption: confirm on data).
-- Rows returned are partial months (typically the latest month) or real gaps. The
-- brazil-energy-matrix export drops incomplete years instead of publishing partial totals.

select
    subsystem_code,
    reference_month,
    hours_count,
    date_diff(date_add(reference_month, interval 1 month), reference_month, day) * 24 as expected_hours

from {{ ref('mart_ons__monthly_generation_by_source') }}
where abs(
    hours_count - date_diff(date_add(reference_month, interval 1 month), reference_month, day) * 24
) > 1
