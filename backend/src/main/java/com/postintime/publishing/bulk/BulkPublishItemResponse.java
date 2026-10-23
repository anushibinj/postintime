package com.postintime.publishing.bulk;

import java.time.Instant;
import java.util.UUID;

public record BulkPublishItemResponse(
        UUID id,
        UUID postId,
        String postTitle,
        int position,
        String status,
        Instant scheduledAt,
        String errorMessage,
        Instant processedAt
) {
}
