-- SLAPENIR Auto-Detection Database Schema
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE api_category AS ENUM (
    'ai_llm', 'cloud_provider', 'developer_tools', 'communication',
    'finance', 'data_analytics', 'productivity', 'infrastructure', 'other'
);

CREATE TYPE strategy_type AS ENUM (
    'bearer', 'aws_sigv4', 'hmac', 'api_key_header', 'oauth2', 'custom'
);

CREATE TABLE api_definitions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    display_name VARCHAR(200) NOT NULL,
    description TEXT,
    category api_category NOT NULL DEFAULT 'other',
    tags TEXT[] DEFAULT '{}',
    env_vars TEXT[] NOT NULL,
    strategy_type strategy_type NOT NULL DEFAULT 'bearer',
    dummy_prefix VARCHAR(100) NOT NULL,
    allowed_hosts TEXT[] NOT NULL,
    header_name VARCHAR(100),
    documentation_url TEXT,
    icon_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_builtin BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_api_definitions_env_vars ON api_definitions USING GIN(env_vars);
CREATE INDEX idx_api_definitions_category ON api_definitions(category);
CREATE INDEX idx_api_definitions_active ON api_definitions(is_active) WHERE is_active = true;

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_api_definitions_updated_at
    BEFORE UPDATE ON api_definitions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
