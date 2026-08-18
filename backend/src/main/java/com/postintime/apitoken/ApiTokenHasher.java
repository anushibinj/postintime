package com.postintime.apitoken;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;

final class ApiTokenHasher {

    private static final SecureRandom RANDOM = new SecureRandom();
    static final String TOKEN_PREFIX = "pit_";

    private ApiTokenHasher() {
    }

    static String generateToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return TOKEN_PREFIX + Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    static String hash(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 is required to store API tokens.", ex);
        }
    }

    static String displayPrefix(String token) {
        return token.substring(0, Math.min(12, token.length()));
    }
}
