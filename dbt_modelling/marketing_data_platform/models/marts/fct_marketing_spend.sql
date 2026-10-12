{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['date', 'platform', 'ad_id'],
    on_schema_change='append_new_columns'
) }}

SELECT
    date,
    platform,
    campaign_id,
    campaign_name,
    ad_group_id,
    ad_group_name,
    ad_id,
    ad_name,
    ad_status,
    account_id,
    currency,
    spend,
    impressions,
    clicks,
    -- Business Metrics
    CASE WHEN impressions > 0 THEN CAST(clicks AS DOUBLE) / impressions ELSE 0 END AS ctr,
    CASE WHEN clicks > 0 THEN spend / clicks ELSE 0 END AS cpc,
    CASE WHEN impressions > 0 THEN (spend / impressions) * 1000 ELSE 0 END AS cpm
FROM {{ ref('int_marketing_ads') }}

{% if is_incremental() %}
    WHERE date > (SELECT MAX(date) FROM {{ this }})
{% endif %}