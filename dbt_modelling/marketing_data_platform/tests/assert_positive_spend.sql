SELECT
    date,
    platform,
    campaign_id,
    ad_id,
    spend,
    impressions,
    clicks
FROM {{ ref('fct_marketing_spend') }}
WHERE spend < 0
   OR impressions < 0
   OR clicks < 0