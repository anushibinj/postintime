package com.postintime.publishing.api;

import com.postintime.publishing.service.PublishingService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/channels/{channelId}/posts/{postId}/targets")
public class PublishingController {

    private final PublishingService publishingService;

    public PublishingController(PublishingService publishingService) {
        this.publishingService = publishingService;
    }

    @GetMapping
    public List<TargetResponse> listTargets(@PathVariable UUID channelId, @PathVariable UUID postId) {
        return publishingService.listTargets(channelId, postId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public List<TargetResponse> createTargets(@PathVariable UUID channelId,
                                              @PathVariable UUID postId,
                                              @Valid @RequestBody CreateTargetsRequest request) {
        return publishingService.createTargets(channelId, postId, request);
    }

    @PostMapping("/{targetId}/publish")
    public PublishActionResponse publish(@PathVariable UUID channelId,
                                         @PathVariable UUID postId,
                                         @PathVariable UUID targetId) {
        return publishingService.publish(channelId, postId, targetId);
    }

    @PostMapping("/{targetId}/mark-published")
    public TargetResponse markPublished(@PathVariable UUID channelId,
                                        @PathVariable UUID postId,
                                        @PathVariable UUID targetId,
                                        @RequestBody(required = false) MarkPublishedRequest request) {
        return publishingService.markPublished(channelId, postId, targetId, request);
    }

    @PostMapping("/{targetId}/reset")
    public TargetResponse resetTarget(@PathVariable UUID channelId,
                                      @PathVariable UUID postId,
                                      @PathVariable UUID targetId) {
        return publishingService.resetTarget(channelId, postId, targetId);
    }
}
