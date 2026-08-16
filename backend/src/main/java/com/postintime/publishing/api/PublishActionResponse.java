package com.postintime.publishing.api;

import java.util.UUID;

public record PublishActionResponse(
        UUID targetId,
        String status,
        String publishingMode,
        PublishInstructionsResponse instructions
) {
}
