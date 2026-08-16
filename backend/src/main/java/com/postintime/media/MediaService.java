package com.postintime.media;

import com.postintime.common.error.BusinessException;
import com.postintime.common.error.ResourceNotFoundException;
import com.postintime.common.security.CurrentUserService;
import com.postintime.user.User;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.io.InputStream;
import java.util.Set;
import java.util.UUID;

@Service
public class MediaService {

    private static final Set<String> ALLOWED_TYPES = Set.of(
            "image/jpeg", "image/png", "image/gif", "image/webp"
    );

    private final MediaRepository mediaRepository;
    private final StorageService storageService;
    private final CurrentUserService currentUserService;
    private final long maxFileSize;

    public MediaService(MediaRepository mediaRepository,
                        StorageService storageService,
                        CurrentUserService currentUserService,
                        @Value("${spring.servlet.multipart.max-file-size:10MB}") String maxFileSize) {
        this.mediaRepository = mediaRepository;
        this.storageService = storageService;
        this.currentUserService = currentUserService;
        this.maxFileSize = parseSize(maxFileSize);
    }

    @Transactional
    public MediaResponse upload(MultipartFile file) {
        validateFile(file);
        User user = currentUserService.getCurrentUser().getUser();
        UUID mediaId = UUID.randomUUID();
        String extension = getExtension(file.getOriginalFilename());
        String storageKey = "users/" + user.getId() + "/temporary/" + mediaId + extension;

        try (InputStream inputStream = file.getInputStream()) {
            storageService.upload(storageKey, inputStream, file.getSize(), file.getContentType());
        } catch (IOException ex) {
            throw new BusinessException("MEDIA_UPLOAD_FAILED", "Failed to upload media.");
        }

        Media media = new Media();
        media.setId(mediaId);
        media.setUser(user);
        media.setStorageKey(storageKey);
        media.setOriginalFilename(file.getOriginalFilename());
        media.setContentType(file.getContentType());
        media.setSizeBytes(file.getSize());
        extractDimensions(file, media);
        mediaRepository.save(media);
        return MediaResponse.from(media, storageService.getPublicUrl(storageKey));
    }

    @Transactional(readOnly = true)
    public Media getOwnedMedia(UUID mediaId) {
        UUID userId = currentUserService.getCurrentUserId();
        return mediaRepository.findByIdAndUserId(mediaId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Media not found."));
    }

    @Transactional
    public void delete(UUID mediaId) {
        Media media = getOwnedMedia(mediaId);
        storageService.delete(media.getStorageKey());
        mediaRepository.delete(media);
    }

    public String getMediaUrl(Media media) {
        return storageService.getPublicUrl(media.getStorageKey());
    }

    private void validateFile(MultipartFile file) {
        if (file.isEmpty()) {
            throw new BusinessException("VALIDATION_ERROR", "File is required.");
        }
        if (file.getSize() > maxFileSize) {
            throw new BusinessException("MEDIA_TOO_LARGE", "File exceeds maximum allowed size.");
        }
        String contentType = file.getContentType();
        if (contentType == null || !ALLOWED_TYPES.contains(contentType)) {
            throw new BusinessException("UNSUPPORTED_MEDIA_TYPE", "Unsupported media type.");
        }
    }

    private void extractDimensions(MultipartFile file, Media media) {
        try (InputStream is = file.getInputStream()) {
            BufferedImage image = ImageIO.read(is);
            if (image != null) {
                media.setWidth(image.getWidth());
                media.setHeight(image.getHeight());
            }
        } catch (IOException ignored) {
            // dimensions optional
        }
    }

    private String getExtension(String filename) {
        if (filename == null || !filename.contains(".")) {
            return "";
        }
        return filename.substring(filename.lastIndexOf('.'));
    }

    private long parseSize(String size) {
        if (size.endsWith("MB")) {
            return Long.parseLong(size.replace("MB", "")) * 1024 * 1024;
        }
        if (size.endsWith("KB")) {
            return Long.parseLong(size.replace("KB", "")) * 1024;
        }
        return Long.parseLong(size);
    }
}
