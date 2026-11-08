package com.postintime.post;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.UUID;

public record BulkDeletePostsRequest(
        @NotNull @NotEmpty @Size(max = 100)
        @Schema(description = "IDs of posts in the channel to delete. At most 100 per request.")
        List<UUID> postIds
) {
}
