package com.postintime.apitoken;

import java.time.Instant;

public record RefreshApiTokenRequest(
        Instant expiresAt,
        Boolean neverExpires
) {
}
