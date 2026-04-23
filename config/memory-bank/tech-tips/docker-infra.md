# Docker & Infrastructure — Tips & Gotchas

## Docker Compose
- Use `depends_on` with `condition: service_healthy` for startup ordering
- Health checks: `test: ["CMD-SHELL", "pg_isready -U user"]` for PostgreSQL
- Named volumes for data persistence, bind mounts for config files

## Caddy
- Auto-TLS works out of the box with a public domain — no cert management needed
- Reverse proxy config: `reverse_proxy service:port` in Caddyfile
- For Tailscale-only access, use internal IPs

## PostgreSQL + pgvector
- HNSW indexes: `CREATE INDEX ON table USING hnsw (embedding vector_cosine_ops)`
- Embedding dimension must match model output (e.g., 384 for all-MiniLM-L6-v2)
- `ILIKE` for case-insensitive text search, vector similarity for semantic search
- Connection string format: `postgresql://user:pass@host:port/dbname`

## GitHub Actions
- `workflow_dispatch` for manual triggers — never auto-deploy on push
- Always verify SSH commands succeeded — they can silently fail
