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
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class BulkPublishProcessorTest {

    private final BulkPublishJobRepository jobRepository = mock(BulkPublishJobRepository.class);
    private final BulkPublishItemRepository itemRepository = mock(BulkPublishItemRepository.class);
    private final SocialAccountRepository socialAccountRepository = mock(SocialAccountRepository.class);
    private final PostTargetRepository postTargetRepository = mock(PostTargetRepository.class);
    private final PublishingService publishingService = mock(PublishingService.class);
    private final BulkPublishProcessor processor = new BulkPublishProcessor(
            jobRepository, itemRepository, socialAccountRepository, postTargetRepository, publishingService);

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
        when(itemRepository.findQueue(any(), any())).thenReturn(List.of());
    }

    @Test
    void returnsFalseWhenNothingIsDue() {
        when(itemRepository.lockNextDueItem(any())).thenReturn(Optional.empty());

        assertThat(processor.processNextDueItem()).isFalse();
    }

    @Test
    void publishesOnePostPerRunSequentiallyAndKeepsGoingAfterFailures() {
        Instant now = Instant.now();
        BulkPublishJob job = job(10, now, post("First"), post("Second"));
        BulkPublishItem first = job.getItems().get(0);
        BulkPublishItem second = job.getItems().get(1);
        when(publishingService.publishToWebhookAccount(any(), any())).thenAnswer(invocation ->
                invocation.getArgument(1) == failing
                        ? PublishResult.failure("WEBHOOK_HTTP_ERROR", "Webhook returned HTTP 500")
                        : PublishResult.ok());

        when(itemRepository.lockNextDueItem(any())).thenReturn(Optional.of(first));
        assertThat(processor.processNextDueItem()).isTrue();

        assertThat(first.getStatus()).isEqualTo(BulkPublishItemStatus.PARTIAL);
        assertThat(first.getErrorMessage()).contains("A failing").contains("HTTP 500");
        assertThat(second.getStatus()).isEqualTo(BulkPublishItemStatus.PENDING);
        assertThat(job.getStatus()).isEqualTo(BulkPublishJobStatus.RUNNING);
        verify(publishingService, never()).publishToWebhookAccount(any(), eq(manual));
        verify(publishingService, never()).publishToWebhookAccount(second.getPost(), working);

        when(itemRepository.lockNextDueItem(any())).thenReturn(Optional.of(second));
        assertThat(processor.processNextDueItem()).isTrue();

        assertThat(second.getStatus()).isEqualTo(BulkPublishItemStatus.PARTIAL);
        assertThat(job.getStatus()).isEqualTo(BulkPublishJobStatus.COMPLETED);
        InOrder order = inOrder(publishingService);
        order.verify(publishingService).publishToWebhookAccount(first.getPost(), failing);
        order.verify(publishingService).publishToWebhookAccount(first.getPost(), working);
        order.verify(publishingService).publishToWebhookAccount(second.getPost(), failing);
        order.verify(publishingService).publishToWebhookAccount(second.getPost(), working);
    }

    @Test
    void marksItemFailedWhenPublisherThrowsAndKeepsTheQueueRunning() {
        BulkPublishJob job = job(5, Instant.now(), post("First"), post("Second"));
        when(itemRepository.lockNextDueItem(any())).thenReturn(Optional.of(job.getItems().get(0)));
        when(publishingService.publishToWebhookAccount(any(), any())).thenThrow(new IllegalStateException("boom"));

        assertThat(processor.processNextDueItem()).isTrue();

        assertThat(job.getItems().get(0).getStatus()).isEqualTo(BulkPublishItemStatus.FAILED);
        assertThat(job.getItems().get(0).getErrorMessage()).contains("boom");
        assertThat(job.getStatus()).isEqualTo(BulkPublishJobStatus.RUNNING);
    }

    @Test
    void skipsAccountsWherePostIsAlreadyPublished() {
        BulkPublishJob job = job(5, Instant.now(), post("Only"));
        Post only = job.getItems().get(0).getPost();
        PostTarget published = new PostTarget();
        published.setStatus(TargetStatus.PUBLISHED);
        when(postTargetRepository.findByPostIdAndSocialAccountId(only.getId(), failing.getId()))
                .thenReturn(Optional.of(published));
        when(postTargetRepository.findByPostIdAndSocialAccountId(only.getId(), working.getId()))
                .thenReturn(Optional.of(published));
        when(itemRepository.lockNextDueItem(any())).thenReturn(Optional.of(job.getItems().get(0)));

        processor.processNextDueItem();

        verify(publishingService, never()).publishToWebhookAccount(any(), any());
        assertThat(job.getItems().get(0).getStatus()).isEqualTo(BulkPublishItemStatus.SKIPPED);
        assertThat(job.getStatus()).isEqualTo(BulkPublishJobStatus.COMPLETED);
    }

    @Test
    void onTimePostsKeepTheirSlots() {
        Instant slot = Instant.now();
        BulkPublishJob job = job(10, slot, post("First"), post("Second"));
        when(publishingService.publishToWebhookAccount(any(), any())).thenReturn(PublishResult.ok());
        when(itemRepository.lockNextDueItem(any())).thenReturn(Optional.of(job.getItems().get(0)));
        when(itemRepository.findQueue(channel.getId(), BulkPublishItemStatus.PENDING))
                .thenReturn(List.of(job.getItems().get(1)));

        processor.processNextDueItem();

        verify(itemRepository, never()).reschedule(any(), any(), any());
    }

    @Test
    void lateQueuePushesLaterPostsBackToKeepTheInterval() {
        // The backend was down: the first post is 30 minutes late and the next two are overdue too.
        Instant slot = Instant.now().minus(Duration.ofMinutes(30));
        BulkPublishJob job = job(10, slot, post("First"), post("Second"), post("Third"));
        BulkPublishItem second = job.getItems().get(1);
        BulkPublishItem third = job.getItems().get(2);
        when(publishingService.publishToWebhookAccount(any(), any())).thenReturn(PublishResult.ok());
        when(itemRepository.lockNextDueItem(any())).thenReturn(Optional.of(job.getItems().get(0)));
        when(itemRepository.findQueue(channel.getId(), BulkPublishItemStatus.PENDING))
                .thenReturn(List.of(second, third));

        Instant before = Instant.now();
        processor.processNextDueItem();
        Instant after = Instant.now();

        var secondSlot = org.mockito.ArgumentCaptor.forClass(Instant.class);
        var thirdSlot = org.mockito.ArgumentCaptor.forClass(Instant.class);
        verify(itemRepository).reschedule(eq(second.getId()), secondSlot.capture(), eq(BulkPublishItemStatus.PENDING));
        verify(itemRepository).reschedule(eq(third.getId()), thirdSlot.capture(), eq(BulkPublishItemStatus.PENDING));
        Duration interval = Duration.ofMinutes(10);
        assertThat(secondSlot.getValue())
                .isBetween(before.minus(BulkPublishProcessor.ON_TIME_GRACE).plus(interval).minusSeconds(1),
                        after.minus(BulkPublishProcessor.ON_TIME_GRACE).plus(interval));
        assertThat(thirdSlot.getValue()).isEqualTo(secondSlot.getValue().plus(interval));
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

    private BulkPublishJob job(int intervalMinutes, Instant firstSlot, Post... posts) {
        BulkPublishJob job = new BulkPublishJob();
        job.setId(UUID.randomUUID());
        job.setChannel(channel);
        job.setIntervalMinutes(intervalMinutes);
        for (int i = 0; i < posts.length; i++) {
            BulkPublishItem item = new BulkPublishItem();
            item.setId(UUID.randomUUID());
            item.setJob(job);
            item.setPost(posts[i]);
            item.setPosition(i);
            item.setScheduledAt(firstSlot.plus(Duration.ofMinutes((long) intervalMinutes * i)));
            job.getItems().add(item);
        }
        return job;
    }
}
