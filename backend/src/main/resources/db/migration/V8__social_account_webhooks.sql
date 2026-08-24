ALTER TABLE social_accounts
    ADD COLUMN webhook_url TEXT,
    ADD COLUMN webhook_auth_type VARCHAR(20) NOT NULL DEFAULT 'NONE',
    ADD COLUMN webhook_username VARCHAR(255),
    ADD COLUMN webhook_password TEXT;

UPDATE social_accounts
SET posting_mode = 'WEBHOOK'
WHERE UPPER(posting_mode) = 'API';
