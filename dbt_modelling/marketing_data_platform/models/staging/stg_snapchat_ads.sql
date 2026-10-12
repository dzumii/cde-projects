{{ config(materialized='view') }}

SELECT
    s.ad_date AS date,
    'snapchat' AS platform,
    s.ad_id,
    NULL AS account_id,
    c.campaign_id,
    a.ad_group_id,
    a.ad_name,
    NULL AS ad_status,
    c.campaign_name,
    ag.ad_group_name,
    s.ad_currency_code AS currency,
    s.ad_spend AS spend,
    s.ad_impressions AS impressions,
    s.ad_clicks AS clicks,
    CURRENT_TIMESTAMP() AS _loaded_at
FROM {{ source('raw', 'snapchat_ads_stats') }} s
LEFT JOIN {{ source('raw', 'snapchat_ad') }} a
    ON s.ad_id = a.ad_id
LEFT JOIN {{ source('raw', 'snapchat_adgroup') }} ag
    ON a.ad_group_id = ag.ad_group_id
LEFT JOIN {{ source('raw', 'snapchat_campaign') }} c
    ON ag.campaign_id = c.campaign_id