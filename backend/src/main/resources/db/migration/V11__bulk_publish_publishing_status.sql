-- Posts are now claimed (status PUBLISHING) before their webhooks are called, outside any
-- transaction. A post that is waiting or being posted can sit in the queue only once.
DROP INDEX uq_bulk_publish_items_pending_post;
CREATE UNIQUE INDEX uq_bulk_publish_items_open_post ON bulk_publish_items(post_id)
    WHERE status IN ('PENDING', 'PUBLISHING');
