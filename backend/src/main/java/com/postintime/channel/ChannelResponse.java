package com.postintime.channel;

import java.time.Instant;
import java.util.UUID;

public record ChannelResponse(
        UUID id,
        String name,
        String slug,
        String description,
        boolean enabled,
        long postCount,
        long socialAccountCount,
        Instant createdAt,
        Instant updatedAt
) {
}
