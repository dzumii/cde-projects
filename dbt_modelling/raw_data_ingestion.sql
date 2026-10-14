--Create a volume to store raw CSVs
CREATE VOLUME IF NOT EXISTS marketing_dev.raw.facebook_files;
CREATE VOLUME IF NOT EXISTS marketing_dev.raw.snapchat_files;

-- ============================================
-- FACEBOOK RAW TABLES
-- ============================================

-- Facebook ads stats (fact table)
CREATE OR REPLACE TABLE marketing_dev.raw.facebook_ads_stats AS
SELECT
    ad_id,
    account_id,
    ad_spend,
    try_cast(ad_impressions AS INT) AS ad_impressions,
    try_cast(ad_clicks AS INT) AS ad_clicks,
    ad_date
FROM read_files('/Volumes/marketing_dev/raw/facebook_files/ads_stats.csv', format => 'csv', header => true);

-- Facebook account dimension
CREATE OR REPLACE TABLE marketing_dev.raw.facebook_account AS
SELECT
    account_id,
    account_name,
    ad_currency_code,
    account_created_at,
    account_updated_at
FROM read_files('/Volumes/marketing_dev/raw/facebook_files/new_acccount_de_randomized.csv', format => 'csv', header => true);

-- Facebook adgroup dimension
CREATE OR REPLACE TABLE marketing_dev.raw.facebook_adgroup AS
SELECT
    ad_group_id,
    ad_group_name,
    ad_group_updated_at
FROM read_files('/Volumes/marketing_dev/raw/facebook_files/new_adgroup_de_randomized.csv', format => 'csv', header => true);

-- Facebook ad dimension (bridge: links ads to campaigns, adgroups, accounts)
CREATE OR REPLACE TABLE marketing_dev.raw.facebook_ad AS
SELECT
    ad_id,
    campaign_id,
    ad_group_id,
    account_id,
    ad_name,
    ad_status,
    ad_updated_at
FROM read_files('/Volumes/marketing_dev/raw/facebook_files/new_ads_de_randomized.csv', format => 'csv', header => true);

-- Facebook campaign dimension
CREATE OR REPLACE TABLE marketing_dev.raw.facebook_campaign AS
SELECT
    campaign_id,
    campaign_name,
    campaign_updated_at
FROM read_files('/Volumes/marketing_dev/raw/facebook_files/new_campaign_de_randomized.csv', format => 'csv', header => true);

-- ============================================
-- SNAPCHAT RAW TABLES
-- ============================================

-- Snapchat ads stats (fact table)
CREATE OR REPLACE TABLE marketing_dev.raw.snapchat_ads_stats AS
SELECT
    ad_detail_id AS ad_id,
    ad_currency_code,
    ad_country,
    ad_spend,
    ad_impressions,
    try_cast(NULLIF(ad_clicks, 'null') AS INT) AS ad_clicks,
    ad_date,
    data_src
FROM read_files('/Volumes/marketing_dev/raw/snapchat_files/snapchat_ads_stats.csv', format => 'csv', header => true);

-- Snapchat campaign dimension
CREATE OR REPLACE TABLE marketing_dev.raw.snapchat_campaign AS
SELECT
    campaign_id,
    account_id,
    campaign_name
FROM read_files('/Volumes/marketing_dev/raw/snapchat_files/snapchat_ads_campaign_history_new_campaign_names.csv', format => 'csv', header => true);

-- Snapchat adgroup dimension
CREATE OR REPLACE TABLE marketing_dev.raw.snapchat_adgroup AS
SELECT
    ad_group_id,
    campaign_id,
    ad_group_name,
    ad_group_updated_at
FROM read_files('/Volumes/marketing_dev/raw/snapchat_files/snapchat_ads_adgroup_history_new_ad_group_names.csv', format => 'csv', header => true);

-- Snapchat ad dimension
CREATE OR REPLACE TABLE marketing_dev.raw.snapchat_ad AS
SELECT
    ad_id,
    ad_group_id,
    ad_name,
    ad_detail_updated_at
FROM read_files('/Volumes/marketing_dev/raw/snapchat_files/snapchat_ads_ad_history_new_ad_names.csv', format => 'csv', header => true);