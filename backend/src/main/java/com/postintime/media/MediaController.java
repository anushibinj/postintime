package com.postintime.media;

import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
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

import java.util.UUID;

import org.springframework.http.HttpStatus;

@RestController
@RequestMapping("/api/v1/media")
public class MediaController {

    private final MediaService mediaService;
    private final MediaFileService mediaFileService;

    public MediaController(MediaService mediaService, MediaFileService mediaFileService) {
        this.mediaService = mediaService;
        this.mediaFileService = mediaFileService;
    }

    @PostMapping(consumes = org.springframework.http.MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public MediaResponse upload(@RequestParam("file") MultipartFile file) {
        return mediaService.upload(file);
    }

    @DeleteMapping("/{mediaId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID mediaId) {
        mediaService.delete(mediaId);
    }

    @GetMapping("/files/**")
    public ResponseEntity<Resource> serveFile(jakarta.servlet.http.HttpServletRequest request) throws Exception {
        String prefix = "/api/v1/media/files/";
        String path = request.getRequestURI();
        String key = path.substring(path.indexOf(prefix) + prefix.length());
        String contentType = mediaFileService.getContentType(key);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(contentType))
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline")
                .body(mediaFileService.load(key));
    }
}
