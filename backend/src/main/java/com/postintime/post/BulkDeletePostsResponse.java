package com.postintime.post;

import io.swagger.v3.oas.annotations.media.Schema;

public record BulkDeletePostsResponse(
        @Schema(description = "Number of posts deleted. IDs not found in the channel are skipped.")
        int deletedCount
) {
}
