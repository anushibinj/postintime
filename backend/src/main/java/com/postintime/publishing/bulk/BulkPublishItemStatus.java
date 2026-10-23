package com.postintime.publishing.bulk;

public enum BulkPublishItemStatus {
    PENDING,
    /** Claimed by the scheduler; its webhooks are being called right now. */
    PUBLISHING,
    PUBLISHED,
    /** At least one account accepted the post and at least one failed. */
    PARTIAL,
    FAILED,
    /** Nothing to publish (no enabled webhook accounts, or already published everywhere). */
    SKIPPED,
    CANCELLED
}
