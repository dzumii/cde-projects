{{ config(materialized='view') }}

WITH aggregated_stats AS (
    SELECT
        ad_id,
        ad_date,
        ad_currency_code,
        SUM(ad_spend) AS ad_spend,
        SUM(COALESCE(ad_impressions, 0)) AS ad_impressions,
        SUM(COALESCE(ad_clicks, 0)) AS ad_clicks
    FROM {{ source('raw', 'snapchat_ads_stats') }}
    GROUP BY ad_id, ad_date, ad_currency_code
)

SELECT
    s.ad_date AS date,
    'snapchat' AS platform,
    CAST(s.ad_id AS STRING) AS ad_id,
    NULL AS account_id,
    CAST(c.campaign_id AS STRING) AS campaign_id,
    CAST(ag.ad_group_id AS STRING) AS ad_group_id,
    a.ad_name,
    NULL AS ad_status,
    c.campaign_name,
    ag.ad_group_name,
    NULL AS account_name,
    s.ad_currency_code AS currency,
    s.ad_spend AS spend,
    s.ad_impressions AS impressions,
    s.ad_clicks AS clicks,
    CURRENT_TIMESTAMP() AS _loaded_at
FROM aggregated_stats s
LEFT JOIN {{ source('raw', 'snapchat_ad') }} a
    ON s.ad_id = a.ad_id
-- Deduplicate adgroup dimension: pick latest ad_group_name per ad_group_id
LEFT JOIN (
    SELECT
        ad_group_id,
        campaign_id,
        ad_group_name,
        ad_group_updated_at
    FROM (
        SELECT
            ad_group_id,
            campaign_id,
            ad_group_name,
            ad_group_updated_at,
            ROW_NUMBER() OVER (
                PARTITION BY ad_group_id
                ORDER BY ad_group_updated_at DESC
            ) AS rn
        FROM {{ source('raw', 'snapchat_adgroup') }}
    )
    WHERE rn = 1
) ag
    ON a.ad_group_id = ag.ad_group_id
LEFT JOIN {{ source('raw', 'snapchat_campaign') }} c
    ON ag.campaign_id = c.campaign_id