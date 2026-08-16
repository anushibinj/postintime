package com.postintime.post;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.UUID;

public record CreatePostRequest(
        @NotBlank @Size(max = 300) String title,
        @Size(max = 10000) String caption,
        UUID mediaId,
        String status
) {
}
