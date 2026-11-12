package com.postintime.common.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class JwtTokenProviderTest {

    private static final String SECRET = "test-secret-key-for-unit-tests-must-be-long-enough";

    private static Claims claims(String token) {
        return Jwts.parser()
                .verifyWith(Keys.hmacShaKeyFor(SECRET.getBytes(StandardCharsets.UTF_8)))
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    @Test
    void tokenLivesForTheConfiguredSevenDays() {
        long sevenDaysMs = Duration.ofDays(7).toMillis();
        JwtTokenProvider provider = new JwtTokenProvider(SECRET, sevenDaysMs);
        UUID userId = UUID.randomUUID();

        String token = provider.generateToken(userId, "a@b.co");
        Claims claims = claims(token);

        assertTrue(provider.validateToken(token));
        assertEquals(userId, provider.getUserId(token));
        // JWT dates have second precision, so allow a second of rounding.
        long lifetime = claims.getExpiration().getTime() - claims.getIssuedAt().getTime();
        assertTrue(Math.abs(lifetime - sevenDaysMs) <= 1000, "lifetime was " + lifetime);
    }

    @Test
    void expiredTokenIsRejected() {
        JwtTokenProvider provider = new JwtTokenProvider(SECRET, -1000);
        assertFalse(provider.validateToken(provider.generateToken(UUID.randomUUID(), "a@b.co")));
    }
}
