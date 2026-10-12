{{ config(materialized='view') }}

SELECT
    s.ad_date AS date,
    'facebook' AS platform,
    CAST(s.ad_id AS STRING) AS ad_id,
    CAST(s.account_id AS STRING) AS account_id,
    CAST(a.campaign_id AS STRING) AS campaign_id,
    CAST(a.ad_group_id AS STRING) AS ad_group_id,
    a.ad_name,
    a.ad_status,
    c.campaign_name,
    ag.ad_group_name,
    ac.account_name,
    ac.ad_currency_code AS currency,
    s.ad_spend AS spend,
    COALESCE(s.ad_impressions, 0) AS impressions,
    COALESCE(s.ad_clicks, 0) AS clicks,
    CURRENT_TIMESTAMP() AS _loaded_at
FROM {{ source('raw', 'facebook_ads_stats') }} s
LEFT JOIN {{ source('raw', 'facebook_ad') }} a
    ON s.ad_id = a.ad_id
LEFT JOIN {{ source('raw', 'facebook_campaign') }} c
    ON a.campaign_id = c.campaign_id
LEFT JOIN {{ source('raw', 'facebook_adgroup') }} ag
    ON a.ad_group_id = ag.ad_group_id
LEFT JOIN {{ source('raw', 'facebook_account') }} ac
    ON s.account_id = ac.account_id