package com.postintime.post;

import java.util.UUID;

public record PostTargetSummary(
        UUID id,
        UUID socialAccountId,
        String platform,
        String name,
        String status
) {
}
