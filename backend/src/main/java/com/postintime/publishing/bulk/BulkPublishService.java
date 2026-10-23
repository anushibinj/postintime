package com.postintime.publishing.bulk;

import com.postintime.channel.Channel;
import com.postintime.channel.ChannelService;
import com.postintime.common.error.BusinessException;
import com.postintime.common.error.ResourceNotFoundException;
import com.postintime.post.Post;
import com.postintime.post.PostRepository;
import com.postintime.social.PostingMode;
import com.postintime.social.SocialAccountRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.UUID;

@Service
public class BulkPublishService {

    public static final int DEFAULT_INTERVAL_MINUTES = 5;
    public static final int MIN_INTERVAL_MINUTES = 5;
    public static final int MAX_INTERVAL_MINUTES = 30;
    public static final int INTERVAL_STEP_MINUTES = 5;

    private static final int RECENT_JOBS_LIMIT = 10;

    private final BulkPublishJobRepository jobRepository;
    private final ChannelService channelService;
    private final PostRepository postRepository;
    private final SocialAccountRepository socialAccountRepository;

    public BulkPublishService(BulkPublishJobRepository jobRepository,
                              ChannelService channelService,
                              PostRepository postRepository,
                              SocialAccountRepository socialAccountRepository) {
        this.jobRepository = jobRepository;
        this.channelService = channelService;
        this.postRepository = postRepository;
        this.socialAccountRepository = socialAccountRepository;
    }

    @Transactional
    public BulkPublishJobResponse createJob(UUID channelId, CreateBulkPublishRequest request) {
        Channel channel = channelService.getOwnedChannel(channelId);
        channelService.ensureChannelEnabled(channel);
        int interval = resolveInterval(request.intervalMinutes());

        boolean hasWebhookAccount = socialAccountRepository.findByChannelIdOrderByNameAsc(channelId).stream()
                .anyMatch(account -> account.isEnabled() && account.getPostingMode() == PostingMode.WEBHOOK);
        if (!hasWebhookAccount) {
            throw new BusinessException("NO_WEBHOOK_ACCOUNTS",
                    "Bulk posting needs at least one enabled webhook social account in this channel.");
        }

        BulkPublishJob job = new BulkPublishJob();
        job.setChannel(channel);
        job.setIntervalMinutes(interval);
        // The first post is due right away; the scheduler spaces out the rest.
        job.setNextRunAt(Instant.now());
        int position = 0;
        for (UUID postId : new LinkedHashSet<>(request.postIds())) {
            Post post = postRepository.findByIdAndChannelId(postId, channelId)
                    .orElseThrow(() -> new ResourceNotFoundException("Post not found."));
            BulkPublishItem item = new BulkPublishItem();
            item.setJob(job);
            item.setPost(post);
            item.setPosition(position++);
            job.getItems().add(item);
        }
        return toResponse(jobRepository.save(job));
    }

    @Transactional(readOnly = true)
    public List<BulkPublishJobResponse> listRecentJobs(UUID channelId) {
        channelService.getOwnedChannel(channelId);
        return jobRepository.findByChannelIdOrderByCreatedAtDesc(channelId, PageRequest.of(0, RECENT_JOBS_LIMIT))
                .stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public BulkPublishJobResponse getJob(UUID channelId, UUID jobId) {
        channelService.getOwnedChannel(channelId);
        return toResponse(jobRepository.findByIdAndChannelId(jobId, channelId)
                .orElseThrow(() -> new ResourceNotFoundException("Bulk publish job not found.")));
    }

    @Transactional
    public BulkPublishJobResponse cancelJob(UUID channelId, UUID jobId) {
        channelService.getOwnedChannel(channelId);
        // Locks the job so cancelling waits for a post that is being published right now.
        BulkPublishJob job = jobRepository.lockByIdAndChannelId(jobId, channelId)
                .orElseThrow(() -> new ResourceNotFoundException("Bulk publish job not found."));
        if (job.getStatus() != BulkPublishJobStatus.RUNNING) {
            throw new BusinessException("INVALID_STATE", "Only running bulk publish jobs can be cancelled.");
        }
        job.setStatus(BulkPublishJobStatus.CANCELLED);
        job.setNextRunAt(null);
        job.getItems().stream()
                .filter(item -> item.getStatus() == BulkPublishItemStatus.PENDING)
                .forEach(item -> item.setStatus(BulkPublishItemStatus.CANCELLED));
        return toResponse(jobRepository.save(job));
    }

    static int resolveInterval(Integer requested) {
        int interval = requested == null ? DEFAULT_INTERVAL_MINUTES : requested;
        if (interval < MIN_INTERVAL_MINUTES || interval > MAX_INTERVAL_MINUTES
                || interval % INTERVAL_STEP_MINUTES != 0) {
            throw new BusinessException("VALIDATION_ERROR",
                    "intervalMinutes must be between " + MIN_INTERVAL_MINUTES + " and " + MAX_INTERVAL_MINUTES
                            + " in steps of " + INTERVAL_STEP_MINUTES + ".");
        }
        return interval;
    }

    private BulkPublishJobResponse toResponse(BulkPublishJob job) {
        List<BulkPublishItemResponse> items = job.getItems().stream()
                .map(item -> new BulkPublishItemResponse(
                        item.getId(),
                        item.getPost().getId(),
                        item.getPost().getTitle(),
                        item.getPosition(),
                        item.getStatus().name().toLowerCase(),
                        item.getErrorMessage(),
                        item.getProcessedAt()
                ))
                .toList();
        int processed = (int) job.getItems().stream()
                .filter(item -> item.getProcessedAt() != null)
                .count();
        int failed = (int) job.getItems().stream()
                .filter(item -> item.getStatus() == BulkPublishItemStatus.FAILED
                        || item.getStatus() == BulkPublishItemStatus.PARTIAL)
                .count();
        return new BulkPublishJobResponse(
                job.getId(),
                job.getChannel().getId(),
                job.getIntervalMinutes(),
                job.getStatus().name().toLowerCase(),
                job.getNextRunAt(),
                items.size(),
                processed,
                failed,
                items,
                job.getCreatedAt(),
                job.getUpdatedAt()
        );
    }
}
