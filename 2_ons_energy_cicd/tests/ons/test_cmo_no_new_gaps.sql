-- Custom test: flags any date/subsystem where the daily mart has fewer than
-- 24 hours of CMO cost data. This does NOT fail the build -- it's a
-- documentation/monitoring test (severity: warn) because the underlying gap
-- is a known, investigated data-source issue (4 full days missing from the
-- ONS CMO source: 2024-02-08, 2024-02-17, 2024-07-13, 2024-12-29 -- likely
-- national holidays/system maintenance, confirmed to affect all 4
-- subsystems equally on the same dates). If NEW dates start showing up here
-- beyond the known 16 rows, that's worth investigating as a real pipeline issue.

select
    subsystem_code,
    reading_date,
    hours_with_cost_data,
    hours_total

from {{ ref('mart_ons__daily_subsystem_balance') }}
where hours_with_cost_data < hours_total
    -- exclude the 4 known gap dates -- anything else showing up here is new/unexpected
    and reading_date not in ('2024-02-08', '2024-02-17', '2024-07-13', '2024-12-29')
