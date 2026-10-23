-- Bulk publishing becomes one queue per channel: every queued post gets its own slot
-- (scheduled_at), and new batches are appended after the last queued post.
ALTER TABLE bulk_publish_items ADD COLUMN scheduled_at TIMESTAMPTZ;

-- Pending items keep the job's spacing, starting at the job's next run.
UPDATE bulk_publish_items i
SET scheduled_at = COALESCE(j.next_run_at, now()) + make_interval(mins => j.interval_minutes * p.rank)
FROM bulk_publish_jobs j,
     (SELECT id, (row_number() OVER (PARTITION BY job_id ORDER BY position) - 1)::int AS rank
      FROM bulk_publish_items
      WHERE status = 'PENDING') p
WHERE i.job_id = j.id AND p.id = i.id;

UPDATE bulk_publish_items
SET scheduled_at = COALESCE(processed_at, created_at)
WHERE scheduled_at IS NULL;

ALTER TABLE bulk_publish_items ALTER COLUMN scheduled_at SET NOT NULL;

-- A post can sit in the queue only once.
UPDATE bulk_publish_items
SET status = 'CANCELLED'
WHERE id IN (
    SELECT id FROM (
        SELECT id, row_number() OVER (PARTITION BY post_id ORDER BY scheduled_at) AS rn
        FROM bulk_publish_items
        WHERE status = 'PENDING'
    ) duplicates
    WHERE rn > 1
);

UPDATE bulk_publish_jobs j
SET status = 'COMPLETED'
WHERE status = 'RUNNING'
  AND NOT EXISTS (SELECT 1 FROM bulk_publish_items i WHERE i.job_id = j.id AND i.status = 'PENDING');

CREATE UNIQUE INDEX uq_bulk_publish_items_pending_post ON bulk_publish_items(post_id) WHERE status = 'PENDING';
CREATE INDEX idx_bulk_publish_items_due ON bulk_publish_items(status, scheduled_at);

-- Scheduling now lives on the items.
ALTER TABLE bulk_publish_jobs DROP COLUMN next_run_at;
