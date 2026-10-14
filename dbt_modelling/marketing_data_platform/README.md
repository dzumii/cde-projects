# Marketing Data Platform

A unified marketing analytics platform built on **Databricks** and **dbt**, combining Facebook Ads and Snapchat Ads data into a single, business-ready marketing spend model with computed performance metrics (CTR, CPC, CPM).

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Data Sources & Schema](#data-sources--schema)
4. [Data Flow & Join Paths](#data-flow--join-paths)
5. [dbt Project Structure](#dbt-project-structure)
6. [Business Metrics](#business-metrics)
7. [Data Quality Tests](#data-quality-tests)
8. [Materialization Strategy](#materialization-strategy)
9. [Environment Separation](#environment-separation)
10. [Setup & Installation](#setup--installation)
11. [Running the Pipeline](#running-the-pipeline)
12. [Data Observability with Elementary](#data-observability-with-elementary)
13. [CI/CD Pipeline](#cicd-pipeline)
14. [Unity Catalog Structure](#unity-catalog-structure)
15. [Production Authentication](#production-authentication)
16. [Troubleshooting](#troubleshooting)

---

## Overview

This project ingests raw advertising data from two platforms — **Facebook Ads** and **Snapchat Ads** — each with different naming conventions, ID formats, and data structures. The platform standardizes, enriches, and unifies them into a single fact table (`fct_marketing_spend`) with consistent columns and computed business metrics.

### Key Challenges Solved

- **Different ID formats**: Facebook uses numeric IDs (LONG), Snapchat uses UUID strings — all unified to STRING in staging
- **Different column names**: Facebook `amount_spent` vs Snapchat `spend` → standardized to `spend`
- **Different click terminology**: Snapchat calls clicks "swipes" → normalized to `clicks`
- **Multi-table joins**: Each platform requires joining fact tables through dimension chains to enrich metrics with campaign/adgroup/ad names
- **Null handling**: Raw data contains literal `"null"` strings and missing values — handled with `try_cast` and `COALESCE`

---

## Architecture

```
UC Volumes (CSV Files)
  marketing_dev.raw.facebook_files/     marketing_dev.raw.snapchat_files/
        |                                      |
        v                                      v
  Raw Tables (9 total)                   Raw Tables (9 total)
  Facebook: 5 tables                     Snapchat: 4 tables
  (stats + 4 dimensions)                (stats + 3 dimensions)
        |                                      |
        v                                      v
  stg_facebook_ads (VIEW)               stg_snapchat_ads (VIEW)
  5-table JOIN:                         4-table JOIN:
  stats -> ad -> campaign               stats -> ad -> adgroup
                -> adgroup                             -> campaign
                -> account
  IDs cast to STRING                    IDs already STRING
  NULLs COALESCE'd to 0                 NULLs COALESCE'd to 0
        |                                      |
        +----------+---------------------+
                   v
  int_marketing_ads (EPHEMERAL)
  UNION ALL of both staging models
  Standardized schema: date, platform, ad_id, campaign_id,
  campaign_name, ad_group_name, ad_name, spend, impressions,
  clicks, currency, ad_status
                   |
                   v
  fct_marketing_spend (INCREMENTAL)
  Final business-ready mart
  Computed metrics: CTR, CPC, CPM
  Incremental strategy: MERGE on (date, platform, ad_id)
```

### Design Principles

- **Medallion-inspired architecture**: Raw -> Staging -> Intermediate -> Marts
- **Type safety**: All IDs cast to STRING at staging to avoid UNION type conflicts
- **Idempotent incremental loads**: MERGE strategy with unique key prevents duplicates
- **Data quality first**: Tests at every layer (staging, intermediate, mart)
- **Observability**: Elementary monitors test results, schema changes, and anomalies

---

## Data Sources & Schema

Raw CSV files are stored in Unity Catalog Volumes and loaded into raw Delta tables.

### Facebook Ads (5 tables — numeric IDs)

| Raw Table | Source File | Role | Row Count | Key Columns |
|---|---|---|---|---|
| `facebook_ads_stats` | `ads_stats.csv` | Fact | 92,300 | ad_id, account_id, ad_spend, ad_impressions, ad_clicks, ad_date |
| `facebook_ad` | `new_ads_de_randomized.csv` | Bridge | 98,926 | ad_id, campaign_id, ad_group_id, account_id, ad_name, ad_status |
| `facebook_campaign` | `new_campaign_de_randomized.csv` | Dimension | 4,162 | campaign_id, campaign_name, campaign_updated_at |
| `facebook_adgroup` | `new_adgroup_de_randomized.csv` | Dimension | 13,433 | ad_group_id, ad_group_name, ad_group_updated_at |
| `facebook_account` | `new_acccount_de_randomized.csv` | Dimension | 16 | account_id, account_name, ad_currency_code |

### Snapchat Ads (4 tables — UUID string IDs)

| Raw Table | Source File | Role | Row Count | Key Columns |
|---|---|---|---|---|
| `snapchat_ads_stats` | `snapchat_ads_stats.csv` | Fact | 2,809 | ad_id (was ad_detail_id), ad_spend, ad_impressions, ad_clicks, ad_date, ad_country |
| `snapchat_ad` | `snapchat_ads_ad_history_new_ad_names.csv` | Dimension | 2,513 | ad_id, ad_group_id, ad_name |
| `snapchat_adgroup` | `snapchat_ads_adgroup_history_new_ad_group_names.csv` | Dimension | 267 | ad_group_id, campaign_id, ad_group_name |
| `snapchat_campaign` | `snapchat_ads_campaign_history_new_campaign_names.csv` | Dimension | 109 | campaign_id, account_id, campaign_name |

### Data Cleaning Applied During Raw Load

- `_rescued_data` column excluded (CSV parsing artifact)
- Facebook `ad_impressions` and `ad_clicks`: `try_cast` from STRING to INT (handles malformed values)
- Snapchat `ad_clicks`: `NULLIF(ad_clicks, 'null')` + `try_cast` (handles literal "null" strings)
- Snapchat `ad_detail_id` renamed to `ad_id` for consistency

---

## Data Flow & Join Paths

### Facebook Join Path (5-table)

```
facebook_ads_stats (fact)
    |
    +-- JOIN facebook_ad ON ad_id         -> gets campaign_id, ad_group_id, account_id, ad_name, ad_status
    |       |
    |       +-- JOIN facebook_campaign ON campaign_id    -> gets campaign_name
    |       +-- JOIN facebook_adgroup ON ad_group_id      -> gets ad_group_name
    |       +-- JOIN facebook_account ON account_id       -> gets account_name, currency
    |
    +-- Produces: date, platform, ad_id, campaign_id, campaign_name, ad_group_name,
                 ad_name, ad_status, account_name, currency, spend, impressions, clicks
```

### Snapchat Join Path (4-table)

```
snapchat_ads_stats (fact)
    |
    +-- JOIN snapchat_ad ON ad_id           -> gets ad_group_id, ad_name
    |       |
    |       +-- JOIN snapchat_adgroup ON ad_group_id  -> gets campaign_id, ad_group_name
    |               |
    |               +-- JOIN snapchat_campaign ON campaign_id -> gets campaign_name
    |
    +-- Produces: date, platform, ad_id, campaign_id, campaign_name, ad_group_name,
                 ad_name, currency, spend, impressions, clicks
```

### Why IDs Are Cast to STRING

Facebook uses numeric IDs (LONG) and Snapchat uses UUID strings. When `int_marketing_ads` performs a `UNION ALL`, Databricks must resolve to a common type. Without explicit casting, Databricks tries to cast Snapchat's UUIDs to BIGINT — which fails with `CAST_INVALID_INPUT`.

**Solution**: All ID columns are cast to `STRING` in both staging models before the UNION.

---

## dbt Project Structure

```
marketing_data_platform/
|-- dbt_project.yml              # Project config, materializations, flags
|-- packages.yml                 # dbt-utils + Elementary packages
|-- .gitignore                   # Excludes target/, profiles.yml, .venv/
|-- models/
|   |-- staging/
|   |   |-- _sources.yml          # 9 raw source table definitions
|   |   |-- _staging_models.yml   # Staging tests (not_null, accepted_values)
|   |   |-- stg_facebook_ads.sql  # 5-table JOIN (stats->ad->campaign+adgroup+account)
|   |   +-- stg_snapchat_ads.sql  # 4-table JOIN (stats->ad->adgroup->campaign)
|   |-- intermediate/
|   |   |-- _intermediate_models.yml  # Intermediate tests
|   |   +-- int_marketing_ads.sql      # UNION ALL of both staging models
|   +-- marts/
|       |-- _marts_models.yml    # Mart tests + metric range checks
|       +-- fct_marketing_spend.sql  # Final incremental mart with CTR/CPC/CPM
|-- tests/
|   |-- assert_positive_spend.sql         # Custom: no negative metrics
|   +-- assert_no_duplicate_campaigns.sql  # Custom: no duplicate records
|-- macros/
+-- .github/
    +-- workflows/
        +-- dbt_ci.yml           # GitHub Actions CI/CD pipeline
```

### Model Dependency Graph

```
[9 raw sources]
      |
      +-- stg_facebook_ads (view)     <- 5-table JOIN
      |         |
      +-- stg_snapchat_ads (view)     <- 4-table JOIN
      |         |
      +---- int_marketing_ads (ephemeral)  <- UNION ALL
                    |
              fct_marketing_spend (incremental)  <- CTR, CPC, CPM
```

---

## Business Metrics

The final mart `fct_marketing_spend` computes three key marketing performance metrics:

| Metric | Formula | Description |
|---|---|---|
| **CTR** | `clicks / impressions` | Click-through rate — percentage of impressions that resulted in clicks |
| **CPC** | `spend / clicks` | Cost per click — average cost for each click |
| **CPM** | `(spend / impressions) * 1,000` | Cost per mille — cost per 1,000 impressions |

All metrics include safe division handling (return 0 when denominator is 0).

### Final Mart Schema

| Column | Type | Description |
|---|---|---|
| `date` | DATE | Performance date |
| `platform` | STRING | 'facebook' or 'snapchat' |
| `campaign_id` | STRING | Campaign identifier (cast to STRING for cross-platform consistency) |
| `campaign_name` | STRING | Campaign display name |
| `ad_group_id` | STRING | Ad group identifier |
| `ad_group_name` | STRING | Ad group display name |
| `ad_id` | STRING | Ad/creative identifier |
| `ad_name` | STRING | Ad/creative display name |
| `ad_status` | STRING | Ad status (ACTIVE, PAUSED, ARCHIVED — Facebook only) |
| `account_id` | STRING | Account identifier (Facebook only) |
| `currency` | STRING | Currency code (e.g., USD, EUR) |
| `spend` | DOUBLE | Ad spend in account currency |
| `impressions` | INT | Ad impressions (COALESCE'd to 0 if NULL) |
| `clicks` | INT | Ad clicks / swipes (COALESCE'd to 0 if NULL) |
| `ctr` | DOUBLE | Click-through rate |
| `cpc` | DOUBLE | Cost per click |
| `cpm` | DOUBLE | Cost per mille |

---

## Data Quality Tests

### Generic Tests (dbt built-in + dbt-utils)

| Test | Model | Column(s) | Purpose |
|---|---|---|---|
| `not_null` | All layers | date, platform, ad_id, campaign_id, spend, impressions, clicks | Ensures key columns are never NULL |
| `accepted_values` | staging | platform | Validates platform = 'facebook' or 'snapchat' |
| `expression_is_true` | fct_marketing_spend | spend >= 0, impressions >= 0, clicks >= 0 | No negative metrics |
| `expression_is_true` | fct_marketing_spend | ctr >= 0 AND ctr <= 1 | CTR must be between 0 and 1 |

### Custom Singular Tests

| Test | File | What It Checks |
|---|---|---|
| `assert_positive_spend` | `tests/assert_positive_spend.sql` | Returns rows where spend < 0, impressions < 0, or clicks < 0 |
| `assert_no_duplicate_campaigns` | `tests/assert_no_duplicate_campaigns.sql` | Returns rows where (date, platform, campaign_id, ad_id) appears more than once |

### Test Layers

```
Staging Tests  ->  validates each platform independently (platform accepted_values, key not_null)
Intermediate   ->  validates the unified UNION (platform, not_null on all metrics)
Mart Tests     ->  validates final output (metric ranges, CTR bounds, no negatives, no duplicates)
```

---

## Materialization Strategy

| Layer | Materialization | Rationale |
|---|---|---|
| **Staging** | `VIEW` | Lightweight, always reflects latest raw data, no storage cost |
| **Intermediate** | `EPHEMERAL` | Not persisted — inlined into downstream queries, avoids storage |
| **Marts** | `INCREMENTAL` (MERGE) | Efficient for growing data — only processes new rows since last run |

### Incremental Configuration

- **Strategy**: `MERGE`
- **Unique key**: `['date', 'platform', 'ad_id']`
- **Schema change**: `append_new_columns`
- **Filter**: `WHERE date > (SELECT MAX(date) FROM {{ this }})`

---

## Environment Separation

| Target | Catalog | Schema | Auth Method | Purpose |
|---|---|---|---|---|
| `dev` | `marketing_dev` | `staging` | Personal Access Token | Local development & testing |
| `ci` | `marketing_dev` | `ci` | CI Token | Pull request validation |
| `prod` | `marketing_prod` | `marts` | Service Principal | Production deployment |

### Why Environment Separation Matters

- **Dev**: Developers can experiment freely without affecting production data
- **CI**: Isolated schema per PR run — tests validate without polluting dev
- **Prod**: Service Principal authentication ensures automated, auditable deploys

---

## Setup & Installation

### Prerequisites

- Python 3.11+
- WSL (Windows Subsystem for Linux) or any Linux/macOS environment
- Databricks workspace with Unity Catalog enabled
- Databricks SQL Warehouse (for dbt connections)
- GitHub account (for CI/CD)

### 1. Clone the Repository

```bash
git clone https://github.com/victoredo/cdc_modelling.git
cd cdc_modelling
```

### 2. Set Up Python Environment

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install dbt-databricks
```

### 3. Configure dbt Profile

Create `~/.dbt/profiles.yml` (outside the repo — never commit this):

```yaml
marketing_data_platform:
  target: dev
  outputs:
    dev:
      type: databricks
      host: <your-workspace>.cloud.databricks.com
      http_path: /sql/1.0/warehouses/<your-warehouse-http-path>
      token: <your-personal-access-token>
      catalog: marketing_dev
      schema: staging
      threads: 4

    ci:
      type: databricks
      host: <your-workspace>.cloud.databricks.com
      http_path: /sql/1.0/warehouses/<your-warehouse-http-path>
      token: <ci-token>
      catalog: marketing_dev
      schema: ci
      threads: 4

    prod:
      type: databricks
      host: <your-workspace>.cloud.databricks.com
      http_path: /sql/1.0/warehouses/<your-warehouse-http-path>
      token: <service-principal-token>
      catalog: marketing_prod
      schema: marts
      threads: 4

elementary:
  target: dev
  outputs:
    dev:
      type: databricks
      host: <your-workspace>.cloud.databricks.com
      http_path: /sql/1.0/warehouses/<your-warehouse-http-path>
      token: <your-personal-access-token>
      catalog: marketing_dev
      schema: staging
      threads: 4
```

### 4. Verify Connection

```bash
dbt debug --target dev
```

### 5. Install dbt Packages

```bash
dbt deps
```

---

## Running the Pipeline

### Full Pipeline Run

```bash
# Install dependencies (dbt-utils, Elementary)
dbt deps

# Build all models (staging views -> intermediate ephemeral -> mart incremental)
dbt run --target dev

# Run all data quality tests
dbt test --target dev

# Generate documentation + lineage graph
dbt docs generate --target dev

# Serve docs locally (then open http://localhost:8080 in your browser)
dbt docs serve --target dev
```

### Run Specific Layers

```bash
# Only staging models
dbt run --select staging --target dev

# Only the final mart
dbt run --select fct_marketing_spend --target dev

# Only tests on the mart
dbt test --select fct_marketing_spend --target dev
```

### Incremental Refresh

```bash
# Full refresh (rebuilds entire incremental table from scratch)
dbt run --select fct_marketing_spend --full-refresh --target dev

# Incremental refresh (only processes new rows since last run)
dbt run --select fct_marketing_spend --target dev
```

---

## Data Observability with Elementary

[Elementary](https://www.elementary-data.com/) provides automated data observability — monitoring test results, schema changes, anomalies, and freshness.

### Install Elementary CLI

```bash
pip install elementary-data
pip install "elementary-data[databricks]"
```

### Run Elementary Models

```bash
# Build Elementary's monitoring tables
dbt run --select elementary --target dev
```

### Generate Observability Report

```bash
edr report --profiles-dir ~/.dbt --profile-target dev
```

This generates an HTML report at `edr_target/elementary_report.html`.

### Required dbt_project.yml Flags

```yaml
flags:
  require_explicit_package_overrides_for_builtin_materializations: false
```

This allows Elementary to override built-in materializations for test result collection.

---

## CI/CD Pipeline

The CI/CD workflow is defined in `.github/workflows/dbt_ci.yml` and uses GitHub Actions.

### Pipeline Flow

```
Feature Branch
      |
      v
Pull Request to main
      |
      v
  CI Validation Job
  1. dbt deps
  2. dbt debug (connection test)
  3. dbt compile (syntax check)
  4. dbt run --select staging
  5. dbt test (all tests)
      |
      | pass
      v
  Merge to main
      |
      v
  Production Deploy Job
  1. dbt deps
  2. dbt run --target prod
  3. dbt test --target prod
```

### GitHub Secrets Required

| Secret Name | Description |
|---|---|
| `DATABRICKS_HOST` | Databricks workspace hostname |
| `DATABRICKS_HTTP_PATH` | SQL Warehouse HTTP path |
| `DATABRICKS_CI_TOKEN` | Token for CI environment |
| `DATABRICKS_PROD_TOKEN` | Service Principal token for production |

---

## Unity Catalog Structure

### Catalogs

| Catalog | Purpose |
|---|---|
| `marketing_dev` | Development & CI environments |
| `marketing_prod` | Production environment |

### Schemas (per catalog)

| Schema | Purpose |
|---|---|
| `raw` | Raw tables loaded from CSV files in UC Volumes |
| `staging` | dbt staging views + Elementary monitoring tables |
| `intermediate` | Intermediate models (ephemeral — not persisted) |
| `marts` | Final business-ready fact tables |

### UC Volumes

| Volume | Contents |
|---|---|
| `marketing_dev.raw.facebook_files` | 5 Facebook Ads CSV files |
| `marketing_dev.raw.snapchat_files` | 4 Snapchat Ads CSV files |

---

## Production Authentication

Production deployments use a **Service Principal** — not a personal access token. This ensures:
- **Auditable access**: All production actions are tied to a machine identity, not a person
- **Non-revocable by individual turnover**: Access persists regardless of team changes
- **Principle of least privilege**: The SP only has access to `marketing_prod` catalog

### Service Principal Details

- **Display name**: `marketing-data-platform-prod`
- **Application ID**: `<application ID>`

### Unity Catalog Permissions

```sql
-- GRANT statements use the application ID (UUID)
GRANT USE CATALOG ON CATALOG marketing_prod TO `<application ID>`;
GRANT CREATE SCHEMA ON CATALOG marketing_prod TO `<application ID>`;
GRANT ALL PRIVILEGES ON CATALOG marketing_prod TO `<application ID>`;
```

> **Important**: Databricks GRANT statements require the **application ID** (UUID format), not the display name.

---

## Troubleshooting

### Common Issues & Fixes

| Issue | Cause | Fix |
|---|---|---|
| `CAST_INVALID_INPUT` on UUID string | Facebook uses LONG IDs, Snapchat uses STRING UUIDs — UNION type conflict | Cast all IDs to `STRING` in both staging models |
| `not_null` test failures on clicks/impressions | Raw data contains literal `"null"` strings | Use `try_cast` + `COALESCE(col, 0)` in staging models |
| `PRINCIPAL_DOES_NOT_EXIST` in GRANT | Using display name instead of application ID | Use the UUID application ID with backticks in GRANT statements |
| `TABLE_OR_VIEW_NOT_FOUND` for fct_marketing_spend | Mart failed to build — cascading test failures | Fix the root cause model error first, then re-run |
| Elementary `Could not find profile named 'elementary'` | Missing `elementary` profile in profiles.yml | Add an `elementary` profile pointing to same Databricks connection |
| `edr report --target dev` fails | Wrong flag name | Use `--profile-target dev` instead of `--target dev` |
| `gio: http://localhost:8080: Operation not supported` | WSL can't auto-open browser | Open `http://localhost:8080` manually in Windows browser |
| `require_explicit_package_overrides` warning | Elementary needs materialization override permission | Add `flags:` block to `dbt_project.yml` |
| `Configuration paths... unused` for elementary | Elementary config under project `models:` key | Remove `elementary:` from `models:` — it's a package, not your project |

---

## Tech Stack

| Component | Technology |
|---|---|
| Cloud Platform | Databricks |
| Data Warehouse | Unity Catalog (Delta Lake) |
| Transformation | dbt (dbt-core + dbt-databricks adapter) |
| Data Quality | dbt tests + dbt-utils |
| Data Observability | Elementary |
| CI/CD | GitHub Actions |
| Authentication (prod) | Databricks Service Principal |
| Development Environment | WSL (Ubuntu) |

---

## Project Deliverables Checklist

- [x] Raw Facebook Ads & Snapchat Ads data loaded into Databricks (Unity Catalog)
- [x] dbt transformation layer: staging -> intermediate -> final mart
- [x] Unified marketing model with consistent structure
- [x] Data quality tests (not_null, accepted_values, expression_is_true, custom singular tests)
- [x] dbt documentation (static HTML docs + lineage graph)
- [x] Elementary for data observability
- [x] Environment separation: dev, CI, production
- [x] Production auth: Service Principal (not personal access token)
- [x] Unity Catalog permissions configured
- [x] Advanced dbt materializations (view, ephemeral, incremental)
- [x] CI/CD workflow (PR -> CI validation -> merge -> production deploy)
- [x] README with setup and architecture documentation

---

## License

This project is part of a case study and is not licensed for redistribution.
