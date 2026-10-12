{{ config(materialized='ephemeral') }}

SELECT
    date,
    platform,
    ad_id,
    account_id,
    campaign_id,
    ad_group_id,
    ad_name,
    ad_status,
    campaign_name,
    ad_group_name,
    currency,
    spend,
    impressions,
    clicks
FROM {{ ref('stg_facebook_ads') }}

UNION ALL

SELECT
    date,
    platform,
    ad_id,
    account_id,
    campaign_id,
    ad_group_id,
    ad_name,
    ad_status,
    campaign_name,
    ad_group_name,
    currency,
    spend,
    impressions,
    clicks
FROM {{ ref('stg_snapchat_ads') }}