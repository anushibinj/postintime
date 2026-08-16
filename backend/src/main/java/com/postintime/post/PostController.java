package com.postintime.post;

import com.postintime.common.api.PageResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/channels/{channelId}/posts")
public class PostController {

    private final PostService postService;

    public PostController(PostService postService) {
        this.postService = postService;
    }

    @GetMapping
    public PageResponse<PostResponse> listPosts(
            @PathVariable UUID channelId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String sort) {
        return postService.listPosts(channelId, page, size, search, status, sort);
    }

    @GetMapping("/{postId}")
    public PostResponse getPost(@PathVariable UUID channelId, @PathVariable UUID postId) {
        return postService.getPost(channelId, postId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PostResponse createPost(@PathVariable UUID channelId,
                                   @Valid @RequestBody CreatePostRequest request) {
        return postService.createPost(channelId, request);
    }

    @PatchMapping("/{postId}")
    public PostResponse updatePost(@PathVariable UUID channelId,
                                   @PathVariable UUID postId,
                                   @Valid @RequestBody UpdatePostRequest request) {
        return postService.updatePost(channelId, postId, request);
    }

    @DeleteMapping("/{postId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deletePost(@PathVariable UUID channelId, @PathVariable UUID postId) {
        postService.deletePost(channelId, postId);
    }
}
