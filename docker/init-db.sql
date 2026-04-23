-- ─────────────────────────────────────────────────
-- claude-memory-stack v1.0.0 | MIT License
-- Author: Rajat Tanwar (@rajat1021)
-- https://github.com/rajat1021/claude-memory-stack
-- ─────────────────────────────────────────────────
--
-- L3 Knowledge + Learning DB — Schema Init
-- Tables: insights, note_chunks, observations, patterns, agents

-- Extensions
CREATE EXTENSION IF NOT EXISTS ruvector VERSION '0.1.0';
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Schema
CREATE SCHEMA IF NOT EXISTS claude_flow;
GRANT ALL ON SCHEMA claude_flow TO claude;
SET search_path TO claude_flow, public;

-- ─────────────────────────────────────────────────
-- Table 1: insights
-- ─────────────────────────────────────────────────
CREATE TABLE claude_flow.insights (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    insight_type      VARCHAR(50) NOT NULL,
    project           VARCHAR(50) DEFAULT 'default',
    model_name        VARCHAR(100),
    title             TEXT NOT NULL,
    content           TEXT NOT NULL,
    embedding         ruvector(384),
    tags              TEXT[] DEFAULT '{}',
    source            VARCHAR(100),
    occurred_on       DATE,
    importance        FLOAT DEFAULT 0.5,
    reference_count   INT DEFAULT 0,
    success           BOOLEAN,
    confidence        FLOAT DEFAULT 0.5,
    success_count     INT DEFAULT 0,
    failure_count     INT DEFAULT 0,
    metadata          JSONB DEFAULT '{}',
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────
-- Table 2: note_chunks
-- ─────────────────────────────────────────────────
CREATE TABLE claude_flow.note_chunks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_path       TEXT NOT NULL,
    chunk_index     INT NOT NULL,
    content         TEXT NOT NULL,
    embedding       ruvector(384),
    metadata        JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(file_path, chunk_index)
);

-- ─────────────────────────────────────────────────
-- Table 3: observations
-- ─────────────────────────────────────────────────
CREATE TABLE claude_flow.observations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID,
    tool_name       VARCHAR(50) NOT NULL,
    summary         TEXT NOT NULL,
    category        VARCHAR(50) DEFAULT 'general',
    embedding       ruvector(384),
    importance      FLOAT DEFAULT 0.5,
    success         BOOLEAN DEFAULT true,
    confidence      FLOAT DEFAULT 0.5,
    metadata        JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────
-- Table 4: patterns
-- ─────────────────────────────────────────────────
CREATE TABLE claude_flow.patterns (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    embedding       ruvector(384),
    pattern_type    VARCHAR(50),
    confidence      FLOAT DEFAULT 0.5,
    success_count   INT DEFAULT 0,
    failure_count   INT DEFAULT 0,
    ewc_importance  FLOAT DEFAULT 1.0,
    metadata        JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────
-- Table 5: agents
-- ─────────────────────────────────────────────────
CREATE TABLE claude_flow.agents (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id          VARCHAR(255) NOT NULL UNIQUE,
    agent_type        VARCHAR(50),
    state             JSONB DEFAULT '{}',
    memory_embedding  ruvector(384),
    created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────
-- HNSW Indexes (embedding columns)
-- ─────────────────────────────────────────────────
CREATE INDEX idx_insights_embedding ON claude_flow.insights
    USING hnsw (embedding ruvector_cosine_ops) WITH (m='16', ef_construction='64');

CREATE INDEX idx_note_chunks_embedding ON claude_flow.note_chunks
    USING hnsw (embedding ruvector_cosine_ops) WITH (m='16', ef_construction='64');

CREATE INDEX idx_observations_embedding ON claude_flow.observations
    USING hnsw (embedding ruvector_cosine_ops) WITH (m='16', ef_construction='64');

CREATE INDEX idx_patterns_embedding ON claude_flow.patterns
    USING hnsw (embedding ruvector_cosine_ops) WITH (m='16', ef_construction='64');

CREATE INDEX idx_agents_embedding ON claude_flow.agents
    USING hnsw (memory_embedding ruvector_cosine_ops) WITH (m='16', ef_construction='64');

-- ─────────────────────────────────────────────────
-- B-tree Indexes — insights
-- ─────────────────────────────────────────────────
CREATE INDEX idx_insights_type ON claude_flow.insights (insight_type);
CREATE INDEX idx_insights_model ON claude_flow.insights (model_name);
CREATE INDEX idx_insights_occurred_on ON claude_flow.insights (occurred_on DESC);
CREATE INDEX idx_insights_project ON claude_flow.insights (project);
CREATE INDEX idx_insights_importance ON claude_flow.insights (importance DESC) WHERE importance > 0.1;
CREATE INDEX idx_insights_tags ON claude_flow.insights USING gin (tags);
CREATE INDEX idx_insights_error_category ON claude_flow.insights ((metadata->>'error_category')) WHERE metadata->>'error_category' IS NOT NULL;

-- Unique constraint
CREATE UNIQUE INDEX idx_insights_title_source ON claude_flow.insights (title, source);

-- ─────────────────────────────────────────────────
-- B-tree Indexes — note_chunks
-- ─────────────────────────────────────────────────
CREATE INDEX idx_note_chunks_file_path ON claude_flow.note_chunks (file_path);

-- ─────────────────────────────────────────────────
-- B-tree Indexes — observations
-- ─────────────────────────────────────────────────
CREATE INDEX idx_observations_category ON claude_flow.observations (category);
CREATE INDEX idx_observations_created ON claude_flow.observations (created_at DESC);
CREATE INDEX idx_observations_tool ON claude_flow.observations (tool_name);
CREATE INDEX idx_observations_failures ON claude_flow.observations (success) WHERE success = false;
