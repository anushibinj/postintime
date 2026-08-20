package com.postintime.publicapi;

import com.postintime.post.CreatePostRequest;
import com.postintime.post.PostResponse;
import com.postintime.post.PostService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/public/channels/{channelId}/posts")
public class PublicPostController {

    private final PostService postService;

    public PublicPostController(PostService postService) {
        this.postService = postService;
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public PostResponse createPost(@PathVariable UUID channelId,
                                   @Valid @RequestBody CreatePostRequest request) {
        return postService.createPost(channelId, request);
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public PostResponse createPostWithMedia(
            @PathVariable UUID channelId,
            @RequestParam String title,
            @RequestParam(required = false) String caption,
            @RequestParam(required = false) UUID mediaId,
            @RequestParam(required = false) String status,
            @RequestParam(value = "media", required = false) MultipartFile media) {
        return postService.createPost(channelId, title, caption, mediaId, status, media);
    }
}
