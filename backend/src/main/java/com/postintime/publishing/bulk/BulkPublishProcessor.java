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
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Publishes the next due post from the bulk publishing queues. Each call handles a single post and
 * calls the social account webhooks one after the other; failures are logged and recorded, never
 * allowed to stop the queue.
 *
 * <p>Webhooks can take up to {@code app.webhook.read-timeout} each, so no transaction is open while
 * they run: a short transaction claims the post (status PUBLISHING), the webhooks are called, and a
 * second short transaction records the outcome.
 */
@Component
public class BulkPublishProcessor {

    private static final Logger log = LoggerFactory.getLogger(BulkPublishProcessor.class);

    /** A post that went out within this long of its slot counts as on time. */
    static final Duration ON_TIME_GRACE = Duration.ofMinutes(1);

    /** Extra time on top of the webhook timeout before a claimed post counts as abandoned. */
    static final Duration STALL_MARGIN = Duration.ofMinutes(5);

    private final BulkPublishJobRepository jobRepository;
    private final BulkPublishItemRepository itemRepository;
    private final SocialAccountRepository socialAccountRepository;
    private final PostTargetRepository postTargetRepository;
    private final PublishingService publishingService;
    private final TransactionTemplate transaction;
    private final Duration webhookTimeout;

    public BulkPublishProcessor(BulkPublishJobRepository jobRepository,
                                BulkPublishItemRepository itemRepository,
                                SocialAccountRepository socialAccountRepository,
                                PostTargetRepository postTargetRepository,
                                PublishingService publishingService,
                                PlatformTransactionManager transactionManager,
                                @Value("${app.webhook.read-timeout:15m}") Duration webhookTimeout) {
        this.jobRepository = jobRepository;
        this.itemRepository = itemRepository;
        this.socialAccountRepository = socialAccountRepository;
        this.postTargetRepository = postTargetRepository;
        this.publishingService = publishingService;
        this.transaction = new TransactionTemplate(transactionManager);
        this.webhookTimeout = webhookTimeout;
    }

    private record Claim(UUID itemId, UUID jobId, UUID channelId, boolean channelEnabled, Post post,
                         int position, Instant scheduledAt, Set<UUID> accountIds) {
    }

    private record Outcome(BulkPublishItemStatus status, String error) {
    }

    /**
     * Publishes the earliest due queued post.
     *
     * @return false when no post was due
     */
    public boolean processNextDueItem() {
        Optional<Claim> claim = transaction.execute(status -> claimNextDueItem());
        if (claim == null || claim.isEmpty()) {
            return false;
        }
        Outcome outcome = publish(claim.get());
        Instant finishedAt = Instant.now();
        transaction.executeWithoutResult(status -> finish(claim.get(), outcome, finishedAt));
        return true;
    }

    /**
     * Fails posts whose claim went silent (the backend stopped mid-post). They are not retried,
     * because the webhook may already have posted them.
     */
    public void failStalledItems() {
        Instant cutoff = Instant.now().minus(webhookTimeout).minus(STALL_MARGIN);
        transaction.executeWithoutResult(status -> {
            int stalled = itemRepository.failStalled(cutoff, "Interrupted: the backend stopped while posting. "
                    + "Check the social accounts before posting it again.");
            if (stalled > 0) {
                log.warn("Bulk publish: marked {} stalled post(s) as failed", stalled);
                jobRepository.completeJobsWithoutOpenItems();
            }
        });
    }

    private Optional<Claim> claimNextDueItem() {
        Optional<BulkPublishItem> due = itemRepository.lockNextDueItem(Instant.now());
        if (due.isEmpty()) {
            return Optional.empty();
        }
        BulkPublishItem item = due.get();
        BulkPublishJob job = item.getJob();
        item.setStatus(BulkPublishItemStatus.PUBLISHING);
        item.setProcessedAt(Instant.now());
        itemRepository.save(item);
        return Optional.of(new Claim(item.getId(), job.getId(), job.getChannel().getId(),
                job.getChannel().isEnabled(), item.getPost(), item.getPosition(), item.getScheduledAt(),
                job.getSocialAccounts().stream().map(SocialAccount::getId).collect(Collectors.toSet())));
    }

    private Outcome publish(Claim claim) {
        if (!claim.channelEnabled()) {
            return new Outcome(BulkPublishItemStatus.SKIPPED, "Channel is disabled.");
        }
        Post post = claim.post();
        List<SocialAccount> accounts = socialAccountRepository
                .findByChannelIdOrderByNameAsc(claim.channelId()).stream()
                .filter(account -> claim.accountIds().contains(account.getId()))
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
                            claim.jobId(), post.getId(), account.getId(), result.errorCode(), reason);
                }
            } catch (RuntimeException ex) {
                failures.add(account.getName() + ": " + ex.getMessage());
                log.warn("Bulk publish job {}: post {} failed on account {}",
                        claim.jobId(), post.getId(), account.getId(), ex);
            }
            // Heartbeat: shows the claim is still alive (see failStalledItems).
            itemRepository.touch(claim.itemId(), Instant.now());
        }

        if (failures.isEmpty()) {
            if (published > 0) {
                return new Outcome(BulkPublishItemStatus.PUBLISHED, null);
            }
            return new Outcome(BulkPublishItemStatus.SKIPPED, accounts.isEmpty()
                    ? "None of the picked social accounts is an enabled webhook account."
                    : "Already published to every picked social account.");
        }
        return new Outcome(published > 0 ? BulkPublishItemStatus.PARTIAL : BulkPublishItemStatus.FAILED,
                String.join("\n", failures));
    }

    private void finish(Claim claim, Outcome outcome, Instant finishedAt) {
        BulkPublishJob job = jobRepository.lockByIdAndChannelId(claim.jobId(), claim.channelId()).orElse(null);
        if (job == null) {
            return; // The channel (and its queue) was deleted while posting.
        }
        job.getItems().stream()
                .filter(item -> item.getId().equals(claim.itemId()))
                .filter(item -> item.getStatus() == BulkPublishItemStatus.PUBLISHING)
                .findFirst()
                .ifPresent(item -> {
                    item.setStatus(outcome.status());
                    item.setErrorMessage(outcome.error());
                    log.info("Bulk publish job {}: post {} (#{}) -> {}",
                            job.getId(), claim.post().getId(), claim.position() + 1, outcome.status());
                });
        if (job.getStatus() == BulkPublishJobStatus.RUNNING && !BulkPublishService.hasOpenItems(job)) {
            job.setStatus(BulkPublishJobStatus.COMPLETED);
            log.info("Bulk publish job {} completed", job.getId());
        }
        jobRepository.save(job);
        keepIntervals(claim.channelId(), claim.scheduledAt(), finishedAt);
    }

    /**
     * Pushes later queued posts back so each still goes out at least its interval after the post
     * before it. Posts only move when the queue runs late (for example, the backend was down or a
     * webhook was slow); when posts go out on time every slot stays as promised.
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

    private boolean alreadyPublished(Post post, SocialAccount account) {
        return postTargetRepository.findByPostIdAndSocialAccountId(post.getId(), account.getId())
                .map(target -> target.getStatus() == TargetStatus.PUBLISHED)
                .orElse(false);
    }
}
