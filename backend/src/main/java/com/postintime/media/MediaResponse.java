package com.postintime.media;

import java.time.Instant;
import java.util.UUID;

public record MediaResponse(
        UUID id,
        String originalFilename,
        String contentType,
        long sizeBytes,
        Integer width,
        Integer height,
        String url
) {
    public static MediaResponse from(Media media, String url) {
        return new MediaResponse(
                media.getId(),
                media.getOriginalFilename(),
                media.getContentType(),
                media.getSizeBytes(),
                media.getWidth(),
                media.getHeight(),
                url
        );
    }
}
