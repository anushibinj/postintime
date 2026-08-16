package com.postintime.post;

import com.postintime.media.MediaResponse;

import java.time.Instant;
import java.util.UUID;

public record PostResponse(
        UUID id,
        UUID channelId,
        String title,
        String caption,
        MediaResponse media,
        String status,
        PublicationSummaryResponse publicationSummary,
        Instant createdAt,
        Instant updatedAt
) {
}
