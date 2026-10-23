-- A bulk publish job publishes several posts of one channel one after another,
-- waiting interval_minutes between posts. next_run_at is when the next pending item is due.
CREATE TABLE bulk_publish_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    interval_minutes INT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'RUNNING',
    next_run_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT ck_bulk_publish_interval CHECK (interval_minutes BETWEEN 5 AND 30 AND interval_minutes % 5 = 0)
);

CREATE INDEX idx_bulk_publish_jobs_channel ON bulk_publish_jobs(channel_id);
CREATE INDEX idx_bulk_publish_jobs_due ON bulk_publish_jobs(status, next_run_at);

CREATE TABLE bulk_publish_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES bulk_publish_jobs(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    position INT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    error_message TEXT,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_bulk_publish_item_post UNIQUE (job_id, post_id)
);

CREATE INDEX idx_bulk_publish_items_job ON bulk_publish_items(job_id, position);
