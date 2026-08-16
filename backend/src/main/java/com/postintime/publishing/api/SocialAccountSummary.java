package com.postintime.publishing.api;

import java.util.UUID;

public record SocialAccountSummary(
        UUID id,
        String platform,
        String name,
        String profileUrl
) {
}
