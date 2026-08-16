CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    title VARCHAR(300) NOT NULL,
    caption TEXT,
    media_id UUID REFERENCES media(id) ON DELETE SET NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_posts_channel_updated ON posts(channel_id, updated_at DESC);
