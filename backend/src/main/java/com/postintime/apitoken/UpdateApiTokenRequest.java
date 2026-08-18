package com.postintime.apitoken;

import jakarta.validation.constraints.Size;

import java.time.Instant;

public record UpdateApiTokenRequest(
        @Size(max = 100) String name,
        Instant expiresAt,
        Boolean neverExpires
) {
}
