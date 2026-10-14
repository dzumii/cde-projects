%sql
-- Create catalog and schemas for environment separation
CREATE CATALOG IF NOT EXISTS marketing_dev;
CREATE CATALOG IF NOT EXISTS marketing_prod;

-- Dev/Staging schemas
CREATE SCHEMA IF NOT EXISTS marketing_dev.raw;
CREATE SCHEMA IF NOT EXISTS marketing_dev.staging;
CREATE SCHEMA IF NOT EXISTS marketing_dev.intermediate;
CREATE SCHEMA IF NOT EXISTS marketing_dev.marts;

-- Production schemas
CREATE SCHEMA IF NOT EXISTS marketing_prod.raw;
CREATE SCHEMA IF NOT EXISTS marketing_prod.staging;
CREATE SCHEMA IF NOT EXISTS marketing_prod.intermediate;
CREATE SCHEMA IF NOT EXISTS marketing_prod.marts;


-- Grant the service principal access to the prod catalog
GRANT USE CATALOG ON CATALOG marketing_prod TO `<application-id-of-your-service-principal>`;
GRANT CREATE SCHEMA ON CATALOG marketing_prod TO `<application-id-of-your-service-principal>`;
GRANT ALL PRIVILEGES ON CATALOG marketing_prod TO `<application-id-of-your-service-principal>`;

-- Read-only access to the shared raw sources used by production staging models
GRANT USE CATALOG ON CATALOG marketing_dev TO `<application-id-of-your-service-principal>`;
GRANT USE SCHEMA ON SCHEMA marketing_dev.raw TO `<application-id-of-your-service-principal>`;
GRANT SELECT ON SCHEMA marketing_dev.raw TO `<application-id-of-your-service-principal>`;