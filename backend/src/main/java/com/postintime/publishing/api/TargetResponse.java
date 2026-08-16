package com.postintime.publishing.api;

import java.time.Instant;
import java.util.UUID;

public record TargetResponse(
        UUID id,
        SocialAccountSummary socialAccount,
        String status,
        String publishingMode,
        Instant publishedAt,
        String externalPostId,
        String externalUrl
) {
}
