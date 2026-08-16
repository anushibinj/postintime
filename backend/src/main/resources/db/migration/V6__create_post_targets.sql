CREATE TABLE post_targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    social_account_id UUID NOT NULL REFERENCES social_accounts(id) ON DELETE CASCADE,
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    publishing_mode VARCHAR(30) NOT NULL DEFAULT 'manual',
    published_at TIMESTAMPTZ,
    external_post_id VARCHAR(255),
    external_url TEXT,
    error_code VARCHAR(100),
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_post_target UNIQUE (post_id, social_account_id)
);

CREATE INDEX idx_post_targets_post ON post_targets(post_id);
CREATE INDEX idx_post_targets_status ON post_targets(status);
CREATE INDEX idx_post_targets_social_account ON post_targets(social_account_id);
