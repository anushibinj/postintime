package com.postintime.publishing.bulk;

import com.postintime.post.Post;
import com.postintime.publishing.domain.PostTargetRepository;
import com.postintime.publishing.domain.PublishResult;
import com.postintime.publishing.domain.TargetStatus;
import com.postintime.publishing.service.PublishingService;
import com.postintime.social.PostingMode;
import com.postintime.social.SocialAccount;
import com.postintime.social.SocialAccountRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Publishes the next due post from the bulk publishing queues. Each call handles a single post and
 * calls the social account webhooks one after the other; failures are logged and recorded, never
 * allowed to stop the queue.
 */
@Component
public class BulkPublishProcessor {

    private static final Logger log = LoggerFactory.getLogger(BulkPublishProcessor.class);

    /** A post that went out within this long of its slot counts as on time. */
    static final Duration ON_TIME_GRACE = Duration.ofMinutes(1);

    private final BulkPublishJobRepository jobRepository;
    private final BulkPublishItemRepository itemRepository;
    private final SocialAccountRepository socialAccountRepository;
    private final PostTargetRepository postTargetRepository;
    private final PublishingService publishingService;

    public BulkPublishProcessor(BulkPublishJobRepository jobRepository,
                                BulkPublishItemRepository itemRepository,
                                SocialAccountRepository socialAccountRepository,
                                PostTargetRepository postTargetRepository,
                                PublishingService publishingService) {
        this.jobRepository = jobRepository;
        this.itemRepository = itemRepository;
        this.socialAccountRepository = socialAccountRepository;
        this.postTargetRepository = postTargetRepository;
        this.publishingService = publishingService;
    }

    /**
     * Publishes the earliest due queued post.
     *
     * @return false when no post was due
     */
    @Transactional
    public boolean processNextDueItem() {
        Optional<BulkPublishItem> due = itemRepository.lockNextDueItem(Instant.now());
        if (due.isEmpty()) {
            return false;
        }
        BulkPublishItem item = due.get();
        BulkPublishJob job = item.getJob();
        processItem(job, item);
        Instant finishedAt = Instant.now();

        boolean jobHasPending = job.getItems().stream()
                .anyMatch(other -> other.getStatus() == BulkPublishItemStatus.PENDING);
        if (!jobHasPending) {
            job.setStatus(BulkPublishJobStatus.COMPLETED);
            log.info("Bulk publish job {} completed", job.getId());
        }
        jobRepository.save(job);
        keepIntervals(job.getChannel().getId(), item.getScheduledAt(), finishedAt);
        return true;
    }

    /**
     * Pushes later queued posts back so each still goes out at least its interval after the post
     * before it. Posts only move when the queue runs late (for example, the backend was down);
     * when posts go out on time every slot stays as promised.
     */
    private void keepIntervals(UUID channelId, Instant slot, Instant finishedAt) {
        Instant lateBase = finishedAt.minus(ON_TIME_GRACE);
        Instant previous = slot.isAfter(lateBase) ? slot : lateBase;
        for (BulkPublishItem next : itemRepository.findQueue(channelId, BulkPublishItemStatus.PENDING)) {
            Instant earliest = previous.plus(Duration.ofMinutes(next.getJob().getIntervalMinutes()))
                    .truncatedTo(ChronoUnit.SECONDS);
            Instant nextSlot = next.getScheduledAt();
            if (nextSlot.isBefore(earliest)) {
                itemRepository.reschedule(next.getId(), earliest, BulkPublishItemStatus.PENDING);
                log.info("Bulk publish queue for channel {} is late; post {} moved to {}",
                        channelId, next.getPost().getId(), earliest);
                nextSlot = earliest;
            }
            previous = nextSlot;
        }
    }

    private void processItem(BulkPublishJob job, BulkPublishItem item) {
        Post post = item.getPost();
        item.setProcessedAt(Instant.now());
        if (!job.getChannel().isEnabled()) {
            finish(job, item, BulkPublishItemStatus.SKIPPED, "Channel is disabled.");
            return;
        }

        List<SocialAccount> accounts = socialAccountRepository
                .findByChannelIdOrderByNameAsc(job.getChannel().getId()).stream()
                .filter(SocialAccount::isEnabled)
                .filter(account -> account.getPostingMode() == PostingMode.WEBHOOK)
                .toList();

        int published = 0;
        List<String> failures = new ArrayList<>();
        // Sequential on purpose: one social media API call at a time.
        for (SocialAccount account : accounts) {
            if (alreadyPublished(post, account)) {
                continue;
            }
            try {
                PublishResult result = publishingService.publishToWebhookAccount(post, account);
                if (result.success()) {
                    published++;
                } else {
                    String reason = result.errorMessage() != null ? result.errorMessage() : result.errorCode();
                    failures.add(account.getName() + ": " + reason);
                    log.warn("Bulk publish job {}: post {} failed on account {} ({}): {}",
                            job.getId(), post.getId(), account.getId(), result.errorCode(), reason);
                }
            } catch (RuntimeException ex) {
                failures.add(account.getName() + ": " + ex.getMessage());
                log.warn("Bulk publish job {}: post {} failed on account {}",
                        job.getId(), post.getId(), account.getId(), ex);
            }
        }

        if (failures.isEmpty()) {
            if (published > 0) {
                finish(job, item, BulkPublishItemStatus.PUBLISHED, null);
            } else {
                finish(job, item, BulkPublishItemStatus.SKIPPED, accounts.isEmpty()
                        ? "No enabled webhook social accounts."
                        : "Already published to every webhook social account.");
            }
        } else {
            finish(job, item, published > 0 ? BulkPublishItemStatus.PARTIAL : BulkPublishItemStatus.FAILED,
                    String.join("\n", failures));
        }
    }

    private boolean alreadyPublished(Post post, SocialAccount account) {
        return postTargetRepository.findByPostIdAndSocialAccountId(post.getId(), account.getId())
                .map(target -> target.getStatus() == TargetStatus.PUBLISHED)
                .orElse(false);
    }

    private void finish(BulkPublishJob job, BulkPublishItem item, BulkPublishItemStatus status, String error) {
        item.setStatus(status);
        item.setErrorMessage(error);
        log.info("Bulk publish job {}: post {} (#{}) -> {}",
                job.getId(), item.getPost().getId(), item.getPosition() + 1, status);
    }
}
