package com.postintime.social;

import java.time.Instant;
import java.util.UUID;

public record SocialAccountResponse(
        UUID id,
        String platform,
        String name,
        String profileUrl,
        String postingMode,
        boolean enabled,
        Instant createdAt,
        Instant updatedAt
) {
}
