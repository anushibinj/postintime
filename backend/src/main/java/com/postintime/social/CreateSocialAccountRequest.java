package com.postintime.social;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateSocialAccountRequest(
        @NotBlank String platform,
        @NotBlank @Size(max = 150) String name,
        String profileUrl,
        String postingMode,
        String webhookUrl,
        String webhookAuthType,
        String webhookUsername,
        String webhookPassword
) {
}
