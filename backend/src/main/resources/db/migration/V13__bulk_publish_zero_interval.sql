-- Bulk posting may run back to back (0 minutes between posts).
ALTER TABLE bulk_publish_jobs DROP CONSTRAINT ck_bulk_publish_interval;
ALTER TABLE bulk_publish_jobs
    ADD CONSTRAINT ck_bulk_publish_interval CHECK (interval_minutes BETWEEN 0 AND 30 AND interval_minutes % 5 = 0);
