package com.postintime.publishing.bulk;

public enum BulkPublishItemStatus {
    PENDING,
    PUBLISHED,
    /** At least one account accepted the post and at least one failed. */
    PARTIAL,
    FAILED,
    /** Nothing to publish (no enabled webhook accounts, or already published everywhere). */
    SKIPPED,
    CANCELLED
}
