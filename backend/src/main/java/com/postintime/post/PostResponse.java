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
        // The score the sender gave the post (0-100); null when it gave none.
        Integer autopublishScore,
        // True when the post was queued for publishing because its score reached the channel's threshold.
        boolean autopublished,
        PublicationSummaryResponse publicationSummary,
        List<PostTargetSummary> targets,
        // When the bulk publishing queue will post this; null when it is not queued.
        Instant bulkPublishScheduledAt,
        Instant createdAt,
        Instant updatedAt
) {
}
