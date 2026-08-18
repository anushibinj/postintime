package com.postintime.apitoken;

import java.time.Instant;
import java.util.UUID;

public record ApiTokenResponse(
        UUID id,
        String name,
        String tokenPrefix,
        String token,
        Instant expiresAt,
        Instant lastUsedAt,
        Instant createdAt
) {
    public static ApiTokenResponse withoutSecret(ApiToken apiToken) {
        return from(apiToken, null);
    }

    public static ApiTokenResponse withSecret(ApiToken apiToken, String token) {
        return from(apiToken, token);
    }

    private static ApiTokenResponse from(ApiToken apiToken, String token) {
        return new ApiTokenResponse(
                apiToken.getId(),
                apiToken.getName(),
                apiToken.getTokenPrefix(),
                token,
                apiToken.getExpiresAt(),
                apiToken.getLastUsedAt(),
                apiToken.getCreatedAt()
        );
    }
}
