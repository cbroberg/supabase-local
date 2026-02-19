-- Enable pgvector for AI embeddings
create extension if not exists vector;

-- Enable pg_cron for scheduled jobs
create extension if not exists pg_cron;

-- Verify both are active
select name, default_version, installed_version 
from pg_available_extensions 
where name in ('vector', 'pg_cron');