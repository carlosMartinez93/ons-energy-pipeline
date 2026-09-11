-- Dimension: calendar/date table for time intelligence in Power BI.
-- Grain: one row per day, spanning the full range of dates present in the
-- daily mart (with a small buffer). Mark this as the model's "Date Table"
-- in Power BI (Table tools > Mark as date table) to enable DAX time
-- intelligence functions (PREVIOUSMONTH, SAMEPERIODLASTYEAR, etc.).
--
-- Pure BigQuery SQL, no dbt package dependency required.

with date_spine as (

    select date_day
    from unnest(
        generate_date_array('2023-12-01', '2025-01-31', interval 1 day)
    ) as date_day

),

renamed as (

    select
        date_day                                   as date,
        extract(year from date_day)                as year,
        extract(month from date_day)                as month_number,
        format_date('%B', date_day)                as month_name,
        format_date('%b %Y', date_day)              as month_year,
        extract(quarter from date_day)              as quarter,
        extract(dayofweek from date_day)            as weekday_number,  -- 1=Sunday..7=Saturday
        format_date('%A', date_day)                 as weekday_name,
        extract(dayofweek from date_day) in (1, 7)  as is_weekend

    from date_spine

)

select * from renamed