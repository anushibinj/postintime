package com.postintime.post;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.UUID;

public record CreatePostRequest(
        @NotBlank @Size(max = 300)
        @Schema(description = "Post title", example = "Launch announcement", maxLength = 300)
        String title,
        @Size(max = 10000)
        @Schema(description = "Post caption", example = "We shipped a new feature.", maxLength = 10000)
        String caption,
        @Schema(description = "Existing media ID from a prior upload. Omit when sending a media file instead.")
        UUID mediaId,
        @Schema(description = "draft or ready", example = "draft")
        String status,
        @Min(0) @Max(100)
        @Schema(description = "Optional autopublish score from 0 to 100. When the channel has autopublish on and the "
                + "score is at or above its threshold, the post is queued for publishing right away.",
                example = "85", minimum = "0", maximum = "100")
        Integer autopublishScore
) {
}
