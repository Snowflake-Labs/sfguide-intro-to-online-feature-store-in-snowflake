-- ============================================================================
-- Snowflake Setup Script for Online Feature Store Demo
-- ============================================================================

USE ROLE ACCOUNTADMIN;

SET USERNAME = (SELECT CURRENT_USER());
SELECT $USERNAME;

-- Set query tag for tracking
ALTER SESSION SET QUERY_TAG = '{"origin":"sf_sit-is", "name":"sfguide_intro_to_online_feature_store", "version":{"major":1, "minor":0}, "attributes":{"is_quickstart":1, "source":"sql"}}';

-- ============================================================================
-- SECTION 1: CREATE ROLE AND GRANT ACCOUNT-LEVEL PERMISSIONS
-- ============================================================================

-- Create role for Feature Store operations and grant to current user
CREATE OR REPLACE ROLE FS_DEMO_ROLE;
GRANT ROLE FS_DEMO_ROLE TO USER identifier($USERNAME);

-- Grant account-level permissions
GRANT CREATE DATABASE ON ACCOUNT TO ROLE FS_DEMO_ROLE;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE FS_DEMO_ROLE;
GRANT CREATE COMPUTE POOL ON ACCOUNT TO ROLE FS_DEMO_ROLE;
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE FS_DEMO_ROLE;
GRANT IMPORT SHARE ON ACCOUNT TO ROLE FS_DEMO_ROLE;

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

-- Create stage for model assets with directory enabled
CREATE OR REPLACE STAGE FS_DEMO_ASSETS
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for storing model assets and data files';

-- ============================================================================
-- SECTION 3: COMPUTE POOL FOR MODEL DEPLOYMENT
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
