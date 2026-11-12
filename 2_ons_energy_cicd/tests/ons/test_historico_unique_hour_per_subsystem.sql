-- Fails if the same subsystem has more than one reading for the same hour
-- (e.g. a year file loaded twice). Duplicates would silently inflate monthly GWh.

select
    subsystem_code,
    reading_at,
    count(*) as readings

from {{ ref('stg_ons__balanco_energia_historico') }}
group by 1, 2
having count(*) > 1
