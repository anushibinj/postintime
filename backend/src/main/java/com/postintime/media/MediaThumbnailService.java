package com.postintime.media;

import com.postintime.common.error.BusinessException;
import net.coobird.thumbnailator.Thumbnails;
import net.coobird.thumbnailator.geometry.Positions;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;

@Service
public class MediaThumbnailService {

    public static final int MIN_SIZE = 16;
    public static final int MAX_SIZE = 512;

    public record Thumbnail(byte[] bytes, String contentType) {}

    public int requireValidSize(Integer size) {
        if (size == null) {
            throw new BusinessException("VALIDATION_ERROR", "size is required.");
        }
        if (size < MIN_SIZE || size > MAX_SIZE) {
            throw new BusinessException(
                    "VALIDATION_ERROR",
                    "size must be between " + MIN_SIZE + " and " + MAX_SIZE + ".");
        }
        return size;
    }

    /**
     * Creates a square, center-cropped JPEG thumbnail at {@code size}×{@code size}.
     */
    public Thumbnail resizeSquare(byte[] originalBytes, int size) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        Thumbnails.of(new ByteArrayInputStream(originalBytes))
                .size(size, size)
                .crop(Positions.CENTER)
                .outputFormat("jpg")
                .outputQuality(0.85)
                .toOutputStream(out);
        return new Thumbnail(out.toByteArray(), "image/jpeg");
    }
}
