-- A post without a score counts as 0. Existing posts get 0 too.
UPDATE posts SET autopublish_score = 0 WHERE autopublish_score IS NULL;
ALTER TABLE posts
    ALTER COLUMN autopublish_score SET DEFAULT 0,
    ALTER COLUMN autopublish_score SET NOT NULL;
