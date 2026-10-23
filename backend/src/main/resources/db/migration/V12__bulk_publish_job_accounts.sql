-- Each bulk publish job posts to the social accounts picked when it was created.
CREATE TABLE bulk_publish_job_accounts (
    job_id UUID NOT NULL REFERENCES bulk_publish_jobs(id) ON DELETE CASCADE,
    social_account_id UUID NOT NULL REFERENCES social_accounts(id) ON DELETE CASCADE,

    PRIMARY KEY (job_id, social_account_id)
);

CREATE INDEX idx_bulk_publish_job_accounts_account ON bulk_publish_job_accounts(social_account_id);

-- Existing jobs keep posting to every webhook account of their channel.
INSERT INTO bulk_publish_job_accounts (job_id, social_account_id)
SELECT j.id, a.id
FROM bulk_publish_jobs j
JOIN social_accounts a ON a.channel_id = j.channel_id
WHERE a.posting_mode = 'WEBHOOK';
