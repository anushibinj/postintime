package com.postintime.publishing.bulk;

import com.postintime.channel.Channel;
import com.postintime.post.Post;
import com.postintime.publishing.domain.PostTarget;
import com.postintime.publishing.domain.PostTargetRepository;
import com.postintime.publishing.domain.PublishResult;
import com.postintime.publishing.domain.TargetStatus;
import com.postintime.publishing.service.PublishingService;
import com.postintime.social.PostingMode;
import com.postintime.social.SocialAccount;
import com.postintime.social.SocialAccountRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class BulkPublishProcessorTest {

    private final BulkPublishJobRepository jobRepository = mock(BulkPublishJobRepository.class);
    private final SocialAccountRepository socialAccountRepository = mock(SocialAccountRepository.class);
    private final PostTargetRepository postTargetRepository = mock(PostTargetRepository.class);
    private final PublishingService publishingService = mock(PublishingService.class);
    private final BulkPublishProcessor processor = new BulkPublishProcessor(
            jobRepository, socialAccountRepository, postTargetRepository, publishingService);

    private Channel channel;
    private SocialAccount failing;
    private SocialAccount working;
    private SocialAccount manual;

    @BeforeEach
    void setUp() {
        channel = new Channel();
        channel.setId(UUID.randomUUID());
        channel.setEnabled(true);
        failing = account("A failing", PostingMode.WEBHOOK, true);
        working = account("B working", PostingMode.WEBHOOK, true);
        manual = account("C manual", PostingMode.MANUAL, true);
        SocialAccount disabled = account("D disabled", PostingMode.WEBHOOK, false);
        when(socialAccountRepository.findByChannelIdOrderByNameAsc(channel.getId()))
                .thenReturn(List.of(failing, working, manual, disabled));
        when(postTargetRepository.findByPostIdAndSocialAccountId(any(), any())).thenReturn(Optional.empty());
        when(jobRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
    }

    @Test
    void returnsFalseWhenNothingIsDue() {
        when(jobRepository.lockNextDueJob(any())).thenReturn(Optional.empty());

        assertThat(processor.processNextDueJob()).isFalse();
    }

    @Test
    void publishesOnePostPerRunSequentiallyAndKeepsGoingAfterFailures() {
        BulkPublishJob job = job(10, post("First"), post("Second"));
        Post first = job.getItems().get(0).getPost();
        Post second = job.getItems().get(1).getPost();
        when(jobRepository.lockNextDueJob(any())).thenReturn(Optional.of(job));
        when(publishingService.publishToWebhookAccount(any(), any())).thenAnswer(invocation ->
                invocation.getArgument(1) == failing
                        ? PublishResult.failure("WEBHOOK_HTTP_ERROR", "Webhook returned HTTP 500")
                        : PublishResult.ok());

        Instant before = Instant.now();
        assertThat(processor.processNextDueJob()).isTrue();

        BulkPublishItem firstItem = job.getItems().get(0);
        assertThat(firstItem.getStatus()).isEqualTo(BulkPublishItemStatus.PARTIAL);
        assertThat(firstItem.getErrorMessage()).contains("A failing").contains("HTTP 500");
        assertThat(job.getItems().get(1).getStatus()).isEqualTo(BulkPublishItemStatus.PENDING);
        assertThat(job.getStatus()).isEqualTo(BulkPublishJobStatus.RUNNING);
        assertThat(job.getNextRunAt()).isAfterOrEqualTo(before.plus(Duration.ofMinutes(10)));
        verify(publishingService, never()).publishToWebhookAccount(any(), org.mockito.ArgumentMatchers.eq(manual));
        verify(publishingService, never()).publishToWebhookAccount(second, working);

        assertThat(processor.processNextDueJob()).isTrue();

        assertThat(job.getItems().get(1).getStatus()).isEqualTo(BulkPublishItemStatus.PARTIAL);
        assertThat(job.getStatus()).isEqualTo(BulkPublishJobStatus.COMPLETED);
        assertThat(job.getNextRunAt()).isNull();
        InOrder order = inOrder(publishingService);
        order.verify(publishingService).publishToWebhookAccount(first, failing);
        order.verify(publishingService).publishToWebhookAccount(first, working);
        order.verify(publishingService).publishToWebhookAccount(second, failing);
        order.verify(publishingService).publishToWebhookAccount(second, working);
    }

    @Test
    void marksItemFailedWhenPublisherThrowsAndStillSchedulesNext() {
        BulkPublishJob job = job(5, post("First"), post("Second"));
        when(jobRepository.lockNextDueJob(any())).thenReturn(Optional.of(job));
        when(publishingService.publishToWebhookAccount(any(), any())).thenThrow(new IllegalStateException("boom"));

        assertThat(processor.processNextDueJob()).isTrue();

        assertThat(job.getItems().get(0).getStatus()).isEqualTo(BulkPublishItemStatus.FAILED);
        assertThat(job.getItems().get(0).getErrorMessage()).contains("boom");
        assertThat(job.getStatus()).isEqualTo(BulkPublishJobStatus.RUNNING);
        assertThat(job.getNextRunAt()).isNotNull();
    }

    @Test
    void skipsAccountsWherePostIsAlreadyPublished() {
        BulkPublishJob job = job(5, post("Only"));
        Post only = job.getItems().get(0).getPost();
        PostTarget published = new PostTarget();
        published.setStatus(TargetStatus.PUBLISHED);
        when(postTargetRepository.findByPostIdAndSocialAccountId(only.getId(), failing.getId()))
                .thenReturn(Optional.of(published));
        when(postTargetRepository.findByPostIdAndSocialAccountId(only.getId(), working.getId()))
                .thenReturn(Optional.of(published));
        when(jobRepository.lockNextDueJob(any())).thenReturn(Optional.of(job));

        processor.processNextDueJob();

        verify(publishingService, never()).publishToWebhookAccount(any(), any());
        assertThat(job.getItems().get(0).getStatus()).isEqualTo(BulkPublishItemStatus.SKIPPED);
        assertThat(job.getStatus()).isEqualTo(BulkPublishJobStatus.COMPLETED);
    }

    private SocialAccount account(String name, PostingMode mode, boolean enabled) {
        SocialAccount account = new SocialAccount();
        account.setId(UUID.randomUUID());
        account.setName(name);
        account.setPostingMode(mode);
        account.setEnabled(enabled);
        account.setChannel(channel);
        return account;
    }

    private Post post(String title) {
        Post post = new Post();
        post.setId(UUID.randomUUID());
        post.setTitle(title);
        post.setChannel(channel);
        return post;
    }

    private BulkPublishJob job(int intervalMinutes, Post... posts) {
        BulkPublishJob job = new BulkPublishJob();
        job.setId(UUID.randomUUID());
        job.setChannel(channel);
        job.setIntervalMinutes(intervalMinutes);
        job.setNextRunAt(Instant.now());
        for (int i = 0; i < posts.length; i++) {
            BulkPublishItem item = new BulkPublishItem();
            item.setJob(job);
            item.setPost(posts[i]);
            item.setPosition(i);
            job.getItems().add(item);
        }
        return job;
    }
}
