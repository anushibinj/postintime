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
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Publishes the next pending item of a due bulk publish job. Each call handles a single post and
 * calls the social account webhooks one after the other; failures are logged and recorded, never
 * allowed to stop the job.
 */
@Component
public class BulkPublishProcessor {

    private static final Logger log = LoggerFactory.getLogger(BulkPublishProcessor.class);

    private final BulkPublishJobRepository jobRepository;
    private final SocialAccountRepository socialAccountRepository;
    private final PostTargetRepository postTargetRepository;
    private final PublishingService publishingService;

    public BulkPublishProcessor(BulkPublishJobRepository jobRepository,
                                SocialAccountRepository socialAccountRepository,
                                PostTargetRepository postTargetRepository,
                                PublishingService publishingService) {
        this.jobRepository = jobRepository;
        this.socialAccountRepository = socialAccountRepository;
        this.postTargetRepository = postTargetRepository;
        this.publishingService = publishingService;
    }

    /**
     * Processes one item of the earliest due job.
     *
     * @return false when no job was due
     */
    @Transactional
    public boolean processNextDueJob() {
        Optional<BulkPublishJob> due = jobRepository.lockNextDueJob(Instant.now());
        if (due.isEmpty()) {
            return false;
        }
        BulkPublishJob job = due.get();
        nextPending(job).ifPresent(item -> processItem(job, item));

        if (nextPending(job).isPresent()) {
            // The interval counts from when this post finished, so slow webhooks never squeeze the gap.
            job.setNextRunAt(Instant.now().plus(Duration.ofMinutes(job.getIntervalMinutes())));
        } else {
            job.setStatus(BulkPublishJobStatus.COMPLETED);
            job.setNextRunAt(null);
            log.info("Bulk publish job {} completed", job.getId());
        }
        jobRepository.save(job);
        return true;
    }

    private Optional<BulkPublishItem> nextPending(BulkPublishJob job) {
        return job.getItems().stream()
                .filter(item -> item.getStatus() == BulkPublishItemStatus.PENDING)
                .findFirst();
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
