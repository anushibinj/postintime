package com.postintime.social;

import jakarta.validation.constraints.Size;

public record UpdateSocialAccountRequest(
        String platform,
        @Size(max = 150) String name,
        String profileUrl,
        String postingMode,
        Boolean enabled,
        String webhookUrl,
        String webhookAuthType,
        String webhookUsername,
        String webhookPassword
) {
}
