-- Autopublish: a channel publishes incoming posts on its own when their score reaches its threshold.
ALTER TABLE channels
    ADD COLUMN autopublish_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN autopublish_threshold INTEGER NOT NULL DEFAULT 80,
    ADD CONSTRAINT chk_channels_autopublish_threshold CHECK (autopublish_threshold BETWEEN 0 AND 100);

-- The score (0-100) the sender gave the post; NULL when it did not give one.
ALTER TABLE posts
    ADD COLUMN autopublish_score INTEGER,
    ADD CONSTRAINT chk_posts_autopublish_score CHECK (autopublish_score IS NULL OR autopublish_score BETWEEN 0 AND 100);
