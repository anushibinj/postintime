package com.postintime.publishing.bulk;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record BulkPublishJobResponse(
        UUID id,
        UUID channelId,
        int intervalMinutes,
        String status,
        Instant nextRunAt,
        int totalItems,
        int processedItems,
        int failedItems,
        List<BulkPublishItemResponse> items,
        Instant createdAt,
        Instant updatedAt
) {
}
