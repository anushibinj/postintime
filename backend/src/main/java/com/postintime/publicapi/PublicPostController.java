package com.postintime.publicapi;

import com.postintime.post.CreatePostRequest;
import com.postintime.post.PostResponse;
import com.postintime.post.PostService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
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
@Tag(name = "Public posts", description = "Create posts in a channel owned by the API token owner")
public class PublicPostController {

    private final PostService postService;

    public PublicPostController(PostService postService) {
        this.postService = postService;
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(
            summary = "Create a post (JSON)",
            description = "Create a post with title, optional caption, optional existing mediaId, and optional status (draft or ready)."
    )
    @ApiResponse(
            responseCode = "201",
            description = "Post created",
            content = @Content(schema = @Schema(implementation = PostResponse.class))
    )
    @ApiResponse(responseCode = "401", description = "Missing or invalid API token", content = @Content)
    @ApiResponse(responseCode = "404", description = "Channel not found for this user", content = @Content)
    public PostResponse createPost(
            @Parameter(description = "Channel ID from GET /api/v1/public/channels", required = true)
            @PathVariable UUID channelId,
            @Valid @RequestBody CreatePostRequest request) {
        return postService.createPost(channelId, request);
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(
            summary = "Create a post with media file",
            description = "Multipart form: required title; optional caption, status, mediaId; optional media file (jpeg, png, gif, or webp). Field name for the file must be media."
    )
    @ApiResponse(
            responseCode = "201",
            description = "Post created",
            content = @Content(schema = @Schema(implementation = PostResponse.class))
    )
    @ApiResponse(responseCode = "401", description = "Missing or invalid API token", content = @Content)
    @ApiResponse(responseCode = "404", description = "Channel not found for this user", content = @Content)
    @ApiResponse(responseCode = "415", description = "Content-Type is not multipart/form-data", content = @Content)
    public PostResponse createPostWithMedia(
            @Parameter(description = "Channel ID from GET /api/v1/public/channels", required = true)
            @PathVariable UUID channelId,
            @RequestParam String title,
            @RequestParam(required = false) String caption,
            @RequestParam(required = false) UUID mediaId,
            @RequestParam(required = false) String status,
            @Parameter(description = "Image file. Form field name: media.")
            @RequestParam(value = "media", required = false) MultipartFile media) {
        return postService.createPost(channelId, title, caption, mediaId, status, media);
    }
}
