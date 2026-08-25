package com.postintime.media;

import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.time.Duration;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/media")
public class MediaController {

    private final MediaService mediaService;
    private final MediaFileService mediaFileService;
    private final MediaThumbnailService mediaThumbnailService;

    public MediaController(MediaService mediaService,
                           MediaFileService mediaFileService,
                           MediaThumbnailService mediaThumbnailService) {
        this.mediaService = mediaService;
        this.mediaFileService = mediaFileService;
        this.mediaThumbnailService = mediaThumbnailService;
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public MediaResponse upload(@RequestParam("file") MultipartFile file) {
        return mediaService.upload(file);
    }

    @DeleteMapping("/{mediaId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID mediaId) {
        mediaService.delete(mediaId);
    }

    /**
     * Serves original media, or a square JPEG thumbnail when {@code size} is set
     * (e.g. {@code ?size=32} → 32×32).
     */
    @GetMapping("/files/**")
    public ResponseEntity<Resource> serveFile(
            jakarta.servlet.http.HttpServletRequest request,
            @RequestParam(required = false) Integer size) throws Exception {
        String prefix = "/api/v1/media/files/";
        String path = request.getRequestURI();
        String key = path.substring(path.indexOf(prefix) + prefix.length());

        if (size == null) {
            String contentType = mediaFileService.getContentType(key);
            return ResponseEntity.ok()
                    .contentType(MediaType.parseMediaType(contentType))
                    .header(HttpHeaders.CONTENT_DISPOSITION, "inline")
                    .cacheControl(CacheControl.maxAge(Duration.ofDays(1)).cachePublic())
                    .body(mediaFileService.load(key));
        }

        int thumbSize = mediaThumbnailService.requireValidSize(size);
        byte[] original = mediaFileService.loadBytes(key);
        try {
            MediaThumbnailService.Thumbnail thumb = mediaThumbnailService.resizeSquare(original, thumbSize);
            return ResponseEntity.ok()
                    .contentType(MediaType.parseMediaType(thumb.contentType()))
                    .header(HttpHeaders.CONTENT_DISPOSITION, "inline")
                    .cacheControl(CacheControl.maxAge(Duration.ofDays(7)).cachePublic())
                    .body(new ByteArrayResource(thumb.bytes()));
        } catch (Exception ex) {
            // Unsupported formats (e.g. some WebP) fall back to the original file.
            String contentType = mediaFileService.getContentType(key);
            return ResponseEntity.ok()
                    .contentType(MediaType.parseMediaType(contentType))
                    .header(HttpHeaders.CONTENT_DISPOSITION, "inline")
                    .cacheControl(CacheControl.maxAge(Duration.ofDays(1)).cachePublic())
                    .body(new ByteArrayResource(original));
        }
    }
}
