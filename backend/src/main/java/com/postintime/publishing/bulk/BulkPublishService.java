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

import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
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
    private final BulkPublishItemRepository itemRepository;
    private final ChannelService channelService;
    private final PostRepository postRepository;
    private final SocialAccountRepository socialAccountRepository;

    public BulkPublishService(BulkPublishJobRepository jobRepository,
                              BulkPublishItemRepository itemRepository,
                              ChannelService channelService,
                              PostRepository postRepository,
                              SocialAccountRepository socialAccountRepository) {
        this.jobRepository = jobRepository;
        this.itemRepository = itemRepository;
        this.channelService = channelService;
        this.postRepository = postRepository;
        this.socialAccountRepository = socialAccountRepository;
    }

    /**
     * Appends the posts to the channel's bulk publishing queue. The first one goes out one interval
     * after the last queued (or last bulk published) post, or right away when the queue is idle.
     */
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

        List<Post> posts = new ArrayList<>();
        for (UUID postId : new LinkedHashSet<>(request.postIds())) {
            posts.add(postRepository.findByIdAndChannelId(postId, channelId)
                    .orElseThrow(() -> new ResourceNotFoundException("Post not found.")));
        }

        // Serialize appends so two batches never compute the same queue tail.
        jobRepository.lockChannelQueue(channelId);
        List<BulkPublishItem> alreadyQueued = itemRepository.findByPostIdInAndStatus(
                posts.stream().map(Post::getId).toList(), BulkPublishItemStatus.PENDING);
        if (!alreadyQueued.isEmpty()) {
            throw new BusinessException("ALREADY_QUEUED", "Already queued for bulk posting: "
                    + String.join(", ", alreadyQueued.stream().map(item -> item.getPost().getTitle()).toList())
                    + ".");
        }

        // Whole-second slots: they are shown to people and survive the database's precision unchanged.
        Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        Instant tail = itemRepository.findQueueTail(channelId, BulkPublishItemStatus.PENDING);
        Duration gap = Duration.ofMinutes(interval);
        Instant slot = tail == null || tail.plus(gap).isBefore(now) ? now : tail.plus(gap);

        BulkPublishJob job = new BulkPublishJob();
        job.setChannel(channel);
        job.setIntervalMinutes(interval);
        int position = 0;
        for (Post post : posts) {
            BulkPublishItem item = new BulkPublishItem();
            item.setJob(job);
            item.setPost(post);
            item.setPosition(position++);
            item.setScheduledAt(slot);
            job.getItems().add(item);
            slot = slot.plus(gap);
        }
        return toResponse(jobRepository.save(job));
    }

    /** Every job that still has queued posts, followed by the most recent finished ones. */
    @Transactional(readOnly = true)
    public List<BulkPublishJobResponse> listRecentJobs(UUID channelId) {
        channelService.getOwnedChannel(channelId);
        List<BulkPublishJob> jobs = new ArrayList<>(jobRepository.findByChannelIdAndStatusOrderByCreatedAtAsc(
                channelId, BulkPublishJobStatus.RUNNING));
        jobs.addAll(jobRepository.findByChannelIdAndStatusNotOrderByCreatedAtDesc(
                channelId, BulkPublishJobStatus.RUNNING, PageRequest.of(0, RECENT_JOBS_LIMIT)));
        return jobs.stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public BulkPublishJobResponse getJob(UUID channelId, UUID jobId) {
        channelService.getOwnedChannel(channelId);
        return toResponse(jobRepository.findByIdAndChannelId(jobId, channelId)
                .orElseThrow(() -> new ResourceNotFoundException("Bulk publish job not found.")));
    }

    @Transactional
    public BulkPublishJobResponse cancelJob(UUID channelId, UUID jobId) {
        BulkPublishJob job = lockRunningJob(channelId, jobId);
        job.getItems().stream()
                .filter(item -> item.getStatus() == BulkPublishItemStatus.PENDING)
                .forEach(item -> item.setStatus(BulkPublishItemStatus.CANCELLED));
        job.setStatus(BulkPublishJobStatus.CANCELLED);
        return toResponse(jobRepository.save(job));
    }

    /** Takes one post out of the queue. Later posts keep their slots. */
    @Transactional
    public BulkPublishJobResponse cancelItem(UUID channelId, UUID jobId, UUID itemId) {
        BulkPublishJob job = lockRunningJob(channelId, jobId);
        BulkPublishItem item = job.getItems().stream()
                .filter(candidate -> candidate.getId().equals(itemId))
                .findFirst()
                .orElseThrow(() -> new ResourceNotFoundException("Bulk publish item not found."));
        if (item.getStatus() != BulkPublishItemStatus.PENDING) {
            throw new BusinessException("INVALID_STATE", "Only queued posts can be removed from the queue.");
        }
        item.setStatus(BulkPublishItemStatus.CANCELLED);
        boolean anyPending = job.getItems().stream()
                .anyMatch(other -> other.getStatus() == BulkPublishItemStatus.PENDING);
        if (!anyPending) {
            boolean anyProcessed = job.getItems().stream().anyMatch(other -> other.getProcessedAt() != null);
            job.setStatus(anyProcessed ? BulkPublishJobStatus.COMPLETED : BulkPublishJobStatus.CANCELLED);
        }
        return toResponse(jobRepository.save(job));
    }

    private BulkPublishJob lockRunningJob(UUID channelId, UUID jobId) {
        channelService.getOwnedChannel(channelId);
        // Locks the job so changes wait for a post that is being published right now.
        BulkPublishJob job = jobRepository.lockByIdAndChannelId(jobId, channelId)
                .orElseThrow(() -> new ResourceNotFoundException("Bulk publish job not found."));
        if (job.getStatus() != BulkPublishJobStatus.RUNNING) {
            throw new BusinessException("INVALID_STATE", "This bulk publish job is no longer running.");
        }
        return job;
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
                        item.getScheduledAt(),
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
        Instant nextRunAt = job.getItems().stream()
                .filter(item -> item.getStatus() == BulkPublishItemStatus.PENDING)
                .map(BulkPublishItem::getScheduledAt)
                .min(Comparator.naturalOrder())
                .orElse(null);
        return new BulkPublishJobResponse(
                job.getId(),
                job.getChannel().getId(),
                job.getIntervalMinutes(),
                job.getStatus().name().toLowerCase(),
                nextRunAt,
                items.size(),
                processed,
                failed,
                items,
                job.getCreatedAt(),
                job.getUpdatedAt()
        );
    }
}
