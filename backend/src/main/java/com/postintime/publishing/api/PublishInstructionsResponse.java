package com.postintime.publishing.api;

import java.util.UUID;

public record PublishInstructionsResponse(
        boolean copyCaption,
        boolean downloadMedia,
        String destinationUrl
) {
}
