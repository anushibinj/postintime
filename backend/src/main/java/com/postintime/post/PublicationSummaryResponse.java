package com.postintime.post;

public record PublicationSummaryResponse(
        long total,
        long published,
        long pending,
        long failed
) {
}
