SELECT
    date,
    platform,
    ad_id,
    COUNT(*) AS record_count
FROM {{ ref('fct_marketing_spend') }}
GROUP BY date, platform, ad_id
HAVING COUNT(*) > 1