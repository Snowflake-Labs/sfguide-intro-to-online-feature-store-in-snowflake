-- ============================================================================
-- Snowflake Setup Script for Online Feature Store Demo
-- ============================================================================

USE ROLE ACCOUNTADMIN;

SET USERNAME = (SELECT CURRENT_USER());
SELECT $USERNAME;

-- ============================================================================
-- SECTION 1: CREATE ROLE AND GRANT ACCOUNT-LEVEL PERMISSIONS
-- ============================================================================

-- Create role for Feature Store operations and grant to current user
CREATE OR REPLACE ROLE FS_DEMO_ROLE;
GRANT ROLE FS_DEMO_ROLE TO USER identifier($USERNAME);

-- Grant account-level permissions
GRANT CREATE DATABASE ON ACCOUNT TO ROLE FS_DEMO_ROLE;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE FS_DEMO_ROLE;
GRANT CREATE INTEGRATION ON ACCOUNT TO ROLE FS_DEMO_ROLE;
GRANT CREATE COMPUTE POOL ON ACCOUNT TO ROLE FS_DEMO_ROLE;
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE FS_DEMO_ROLE;
GRANT IMPORT SHARE ON ACCOUNT TO ROLE FS_DEMO_ROLE;
GRANT CREATE ROLE ON ACCOUNT TO ROLE FS_DEMO_ROLE;
GRANT MANAGE GRANTS ON ACCOUNT TO ROLE FS_DEMO_ROLE;

-- ============================================================================
-- SECTION 2: SWITCH TO ROLE AND CREATE RESOURCES
-- ============================================================================

USE ROLE FS_DEMO_ROLE;

-- Create warehouse
CREATE OR REPLACE WAREHOUSE FS_DEMO_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for Feature Store demo';

-- Create database and schema
CREATE OR REPLACE DATABASE FEATURE_STORE_DEMO
    COMMENT = 'Database for Feature Store with taxi trip prediction';

CREATE OR REPLACE SCHEMA FEATURE_STORE_DEMO.TAXI_FEATURES
    COMMENT = 'Schema for taxi features and online feature store';

-- Use the created resources
USE WAREHOUSE FS_DEMO_WH;
USE DATABASE FEATURE_STORE_DEMO;
USE SCHEMA TAXI_FEATURES;

-- Create stage for model assets
CREATE OR REPLACE STAGE FS_DEMO_ASSETS
    COMMENT = 'Stage for storing model assets';

-- ============================================================================
-- SECTION 3: EXTERNAL ACCESS INTEGRATION
-- ============================================================================

-- Create network rule to allow all external access (for PyPI, external APIs, etc.)
CREATE OR REPLACE NETWORK RULE allow_all_rule
    TYPE = 'HOST_PORT'
    MODE = 'EGRESS'
    VALUE_LIST = ('0.0.0.0:443', '0.0.0.0:80');

-- Create external access integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION allow_all_integration
    ALLOWED_NETWORK_RULES = (allow_all_rule)
    ENABLED = true;

GRANT USAGE ON INTEGRATION allow_all_integration TO ROLE FS_DEMO_ROLE;

-- ============================================================================
-- SECTION 4: GIT INTEGRATION
-- ============================================================================

-- Create API integration with GitHub
CREATE OR REPLACE API INTEGRATION GITHUB_INTEGRATION_FS_DEMO
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/')
    ENABLED = true
    COMMENT = 'Git integration for Feature Store demo repository';

-- Create Git repository integration
CREATE OR REPLACE GIT REPOSITORY GITHUB_INTEGRATION_FS_DEMO
    ORIGIN = 'https://github.com/Snowflake-Labs/sfguide-intro-to-online-feature-store-in-snowflake.git'
    API_INTEGRATION = 'GITHUB_INTEGRATION_FS_DEMO'
    COMMENT = 'Feature Store demo GitHub repository';

-- Fetch the latest files from GitHub
ALTER GIT REPOSITORY GITHUB_INTEGRATION_FS_DEMO FETCH;

-- ============================================================================
-- SECTION 5: CREATE NOTEBOOK FROM GIT REPOSITORY
-- ============================================================================

-- Create notebook from the Git repository
CREATE OR REPLACE NOTEBOOK FEATURE_STORE_DEMO.TAXI_FEATURES.ONLINE_FEATURE_STORE_NOTEBOOK
    FROM '@FEATURE_STORE_DEMO.TAXI_FEATURES.GITHUB_INTEGRATION_FS_DEMO/branches/main'
    MAIN_FILE = 'notebooks/0_start_here.ipynb'
    QUERY_WAREHOUSE = FS_DEMO_WH
    RUNTIME_NAME = 'SYSTEM$BASIC_RUNTIME'
    COMPUTE_POOL = 'SYSTEM_COMPUTE_POOL_CPU'
    IDLE_AUTO_SHUTDOWN_TIME_SECONDS = 3600
    COMMENT = 'Online Feature Store Demo Notebook';

-- Add live version and set external access
ALTER NOTEBOOK FEATURE_STORE_DEMO.TAXI_FEATURES.ONLINE_FEATURE_STORE_NOTEBOOK ADD LIVE VERSION FROM LAST;
ALTER NOTEBOOK FEATURE_STORE_DEMO.TAXI_FEATURES.ONLINE_FEATURE_STORE_NOTEBOOK SET EXTERNAL_ACCESS_INTEGRATIONS = ('allow_all_integration');

-- ============================================================================
-- SECTION 6: COMPUTE POOL FOR MODEL DEPLOYMENT (OPTIONAL)
-- ============================================================================

-- Create compute pool for SPCS model serving
CREATE COMPUTE POOL IF NOT EXISTS trip_eta_prediction_pool
    MIN_NODES = 1
    MAX_NODES = 1
    INSTANCE_FAMILY = 'CPU_X64_M'
    AUTO_RESUME = TRUE
    AUTO_SUSPEND_SECS = 300
    COMMENT = 'Compute pool for taxi ETA prediction service';

-- Grant usage on compute pool
GRANT USAGE ON COMPUTE POOL trip_eta_prediction_pool TO ROLE FS_DEMO_ROLE;
GRANT OPERATE ON COMPUTE POOL trip_eta_prediction_pool TO ROLE FS_DEMO_ROLE;

-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================

