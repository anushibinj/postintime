package com.postintime.publishing.service;

import com.postintime.common.error.BusinessException;
import com.postintime.common.error.ResourceNotFoundException;
import com.postintime.post.Post;
import com.postintime.post.PostService;
import com.postintime.publishing.api.CreateTargetsRequest;
import com.postintime.publishing.api.MarkPublishedRequest;
import com.postintime.publishing.api.PublishActionResponse;
import com.postintime.publishing.api.PublishInstructionsResponse;
import com.postintime.publishing.api.SocialAccountSummary;
import com.postintime.publishing.api.TargetResponse;
import com.postintime.publishing.domain.PostTarget;
import com.postintime.publishing.domain.PostTargetRepository;
import com.postintime.publishing.domain.PublishContext;
import com.postintime.publishing.domain.TargetStatus;
import com.postintime.publishing.publisher.PublisherFactory;
import com.postintime.publishing.publisher.SocialMediaPublisher;
import com.postintime.social.SocialAccount;
import com.postintime.social.SocialAccountRepository;
import com.postintime.social.SocialAccountService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class PublishingService {

    private final PostTargetRepository postTargetRepository;
    private final PostService postService;
    private final SocialAccountService socialAccountService;
    private final SocialAccountRepository socialAccountRepository;
    private final PublisherFactory publisherFactory;

    public PublishingService(PostTargetRepository postTargetRepository,
                             PostService postService,
                             SocialAccountService socialAccountService,
                             SocialAccountRepository socialAccountRepository,
                             PublisherFactory publisherFactory) {
        this.postTargetRepository = postTargetRepository;
        this.postService = postService;
        this.socialAccountService = socialAccountService;
        this.socialAccountRepository = socialAccountRepository;
        this.publisherFactory = publisherFactory;
    }

    @Transactional(readOnly = true)
    public List<TargetResponse> listTargets(UUID channelId, UUID postId) {
        Post post = postService.getOwnedPost(channelId, postId);
        return postTargetRepository.findByPostId(post.getId()).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public List<TargetResponse> createTargets(UUID channelId, UUID postId, CreateTargetsRequest request) {
        Post post = postService.getOwnedPost(channelId, postId);
        List<SocialAccount> accounts = socialAccountRepository.findByIdInAndChannelId(
                request.socialAccountIds(), channelId);

        if (accounts.size() != request.socialAccountIds().size()) {
            throw new BusinessException("CROSS_CHANNEL_TARGET",
                    "One or more social accounts do not belong to this channel.");
        }

        List<TargetResponse> results = new ArrayList<>();
        for (SocialAccount account : accounts) {
            socialAccountService.ensureAccountEnabled(account);
            if (postTargetRepository.existsByPostIdAndSocialAccountId(post.getId(), account.getId())) {
                postTargetRepository.findByPostId(post.getId()).stream()
                        .filter(t -> t.getSocialAccount().getId().equals(account.getId()))
                        .findFirst()
                        .ifPresent(t -> results.add(toResponse(t)));
                continue;
            }
            PostTarget target = new PostTarget();
            target.setPost(post);
            target.setSocialAccount(account);
            target.setPublishingMode(account.getPostingMode());
            results.add(toResponse(postTargetRepository.save(target)));
        }
        return results;
    }

    @Transactional
    public PublishActionResponse publish(UUID channelId, UUID postId, UUID targetId) {
        PostTarget target = getOwnedTarget(channelId, postId, targetId);
        SocialMediaPublisher publisher = publisherFactory.getPublisher(target.getPublishingMode());
        publisher.publish(new PublishContext(target.getPost(), target.getSocialAccount(), target));
        return new PublishActionResponse(
                target.getId(),
                target.getStatus().name().toLowerCase(),
                target.getPublishingMode().name().toLowerCase(),
                new PublishInstructionsResponse(
                        true,
                        target.getPost().getMedia() != null,
                        target.getSocialAccount().getProfileUrl()
                )
        );
    }

    @Transactional
    public TargetResponse markPublished(UUID channelId, UUID postId, UUID targetId,
                                        MarkPublishedRequest request) {
        PostTarget target = getOwnedTarget(channelId, postId, targetId);
        if (target.getStatus() != TargetStatus.PUBLISHED) {
            target.setStatus(TargetStatus.PUBLISHED);
            target.setPublishedAt(Instant.now());
        }
        if (request != null && request.externalUrl() != null) {
            target.setExternalUrl(request.externalUrl());
        }
        return toResponse(postTargetRepository.save(target));
    }

    @Transactional
    public TargetResponse resetTarget(UUID channelId, UUID postId, UUID targetId) {
        PostTarget target = getOwnedTarget(channelId, postId, targetId);
        target.setStatus(TargetStatus.PENDING);
        target.setPublishedAt(null);
        target.setErrorCode(null);
        target.setErrorMessage(null);
        return toResponse(postTargetRepository.save(target));
    }

    private PostTarget getOwnedTarget(UUID channelId, UUID postId, UUID targetId) {
        postService.getOwnedPost(channelId, postId);
        return postTargetRepository.findByIdAndPostId(targetId, postId)
                .orElseThrow(() -> new ResourceNotFoundException("Post target not found."));
    }

    private TargetResponse toResponse(PostTarget target) {
        SocialAccount account = target.getSocialAccount();
        return new TargetResponse(
                target.getId(),
                new SocialAccountSummary(
                        account.getId(),
                        account.getPlatform().name().toLowerCase(),
                        account.getName(),
                        account.getProfileUrl()
                ),
                target.getStatus().name().toLowerCase(),
                target.getPublishingMode().name().toLowerCase(),
                target.getPublishedAt(),
                target.getExternalPostId(),
                target.getExternalUrl()
        );
    }
}
