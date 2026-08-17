package com.postintime.post;

import com.postintime.media.MediaResponse;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record PostResponse(
        UUID id,
        UUID channelId,
        String title,
        String caption,
        MediaResponse media,
        String status,
        PublicationSummaryResponse publicationSummary,
        List<PostTargetSummary> targets,
        Instant createdAt,
        Instant updatedAt
) {
}
