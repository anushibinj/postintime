package com.postintime.post;

import com.postintime.channel.Channel;
import com.postintime.channel.ChannelService;
import com.postintime.common.api.PageResponse;
import com.postintime.common.error.BusinessException;
import com.postintime.common.error.ResourceNotFoundException;
import com.postintime.media.MediaResponse;
import com.postintime.media.MediaService;
import com.postintime.publishing.domain.PostTarget;
import com.postintime.publishing.domain.PostTargetRepository;
import com.postintime.publishing.domain.TargetStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class PostService {

    private final PostRepository postRepository;
    private final ChannelService channelService;
    private final MediaService mediaService;
    private final PostTargetRepository postTargetRepository;

    public PostService(PostRepository postRepository,
                       ChannelService channelService,
                       MediaService mediaService,
                       PostTargetRepository postTargetRepository) {
        this.postRepository = postRepository;
        this.channelService = channelService;
        this.mediaService = mediaService;
        this.postTargetRepository = postTargetRepository;
    }

    @Transactional(readOnly = true)
    public PageResponse<PostResponse> listPosts(UUID channelId, int page, int size, String search,
                                                String status, String sort) {
        Channel channel = channelService.getOwnedChannel(channelId);
        PostStatus postStatus = parseStatus(status);
        Sort sortSpec = parseSort(sort);
        Page<Post> posts = postRepository.searchPosts(
                channel.getId(),
                search == null || search.isBlank() ? "" : search,
                postStatus,
                PageRequest.of(page, size, sortSpec)
        );
        return PageResponse.of(
                posts.getContent().stream().map(this::toResponse).toList(),
                page,
                size,
                posts.getTotalElements()
        );
    }

    @Transactional(readOnly = true)
    public PostResponse getPost(UUID channelId, UUID postId) {
        return toResponse(getOwnedPost(channelId, postId));
    }

    @Transactional
    public PostResponse createPost(UUID channelId, CreatePostRequest request) {
        Channel channel = channelService.getOwnedChannel(channelId);
        channelService.ensureChannelEnabled(channel);
        Post post = new Post();
        post.setChannel(channel);
        post.setTitle(request.title());
        post.setCaption(request.caption());
        post.setStatus(parseStatusRequired(request.status()));
        if (request.mediaId() != null) {
            post.setMedia(mediaService.getOwnedMedia(request.mediaId()));
        }
        return toResponse(postRepository.save(post));
    }

    @Transactional
    public PostResponse updatePost(UUID channelId, UUID postId, UpdatePostRequest request) {
        Post post = getOwnedPost(channelId, postId);
        if (request.title() != null) {
            post.setTitle(request.title());
        }
        if (request.caption() != null) {
            post.setCaption(request.caption());
        }
        if (request.status() != null) {
            post.setStatus(parseStatusRequired(request.status()));
        }
        if (request.mediaId() != null) {
            post.setMedia(mediaService.getOwnedMedia(request.mediaId()));
        }
        return toResponse(postRepository.save(post));
    }

    @Transactional
    public void deletePost(UUID channelId, UUID postId) {
        Post post = getOwnedPost(channelId, postId);
        postRepository.delete(post);
    }

    public Post getOwnedPost(UUID channelId, UUID postId) {
        channelService.getOwnedChannel(channelId);
        return postRepository.findByIdAndChannelId(postId, channelId)
                .orElseThrow(() -> new ResourceNotFoundException("Post not found."));
    }

    private PostResponse toResponse(Post post) {
        MediaResponse mediaResponse = null;
        if (post.getMedia() != null) {
            mediaResponse = MediaResponse.from(post.getMedia(), mediaService.getMediaUrl(post.getMedia()));
        }
        List<PostTarget> targets = postTargetRepository.findByPostId(post.getId());
        long total = targets.size();
        long published = targets.stream().filter(t -> t.getStatus() == TargetStatus.PUBLISHED).count();
        long pending = targets.stream().filter(t -> t.getStatus() == TargetStatus.PENDING).count();
        long failed = targets.stream().filter(t -> t.getStatus() == TargetStatus.FAILED).count();
        List<PostTargetSummary> targetSummaries = targets.stream()
                .map(t -> new PostTargetSummary(
                        t.getId(),
                        t.getSocialAccount().getId(),
                        t.getSocialAccount().getPlatform().name().toLowerCase(),
                        t.getSocialAccount().getName(),
                        t.getStatus().name().toLowerCase()
                ))
                .toList();
        return new PostResponse(
                post.getId(),
                post.getChannel().getId(),
                post.getTitle(),
                post.getCaption(),
                mediaResponse,
                post.getStatus().name().toLowerCase(),
                new PublicationSummaryResponse(total, published, pending, failed),
                targetSummaries,
                post.getCreatedAt(),
                post.getUpdatedAt()
        );
    }

    private PostStatus parseStatusRequired(String status) {
        if (status == null || status.isBlank()) {
            return PostStatus.DRAFT;
        }
        return PostStatus.valueOf(status.toUpperCase());
    }

    private PostStatus parseStatus(String status) {
        if (status == null || status.isBlank()) {
            return null;
        }
        return PostStatus.valueOf(status.toUpperCase());
    }

    private Sort parseSort(String sort) {
        if (sort == null || sort.isBlank()) {
            return Sort.by(Sort.Direction.DESC, "updatedAt");
        }
        String[] parts = sort.split(",");
        String field = parts[0];
        Sort.Direction direction = parts.length > 1 && parts[1].equalsIgnoreCase("asc")
                ? Sort.Direction.ASC : Sort.Direction.DESC;
        return Sort.by(direction, field);
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value;
    }
}
