package com.postintime.post;

import jakarta.validation.constraints.Size;

import java.util.UUID;

public record UpdatePostRequest(
        @Size(max = 300) String title,
        @Size(max = 10000) String caption,
        UUID mediaId,
        String status
) {
}
