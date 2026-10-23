package com.postintime.publishing.bulk;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BulkPublishItemRepository extends JpaRepository<BulkPublishItem, UUID> {

    /**
     * Locks the earliest due queued post together with its job. SKIP LOCKED keeps two backend
     * instances from claiming the same post, and skips a job that is being cancelled. Channels
     * with a post being published right now are skipped so a channel never posts in parallel.
     */
    @Query(value = """
            SELECT i.* FROM bulk_publish_items i
            JOIN bulk_publish_jobs j ON j.id = i.job_id
            WHERE i.status = 'PENDING' AND j.status = 'RUNNING' AND i.scheduled_at <= :now
              AND NOT EXISTS (
                  SELECT 1 FROM bulk_publish_items busy
                  JOIN bulk_publish_jobs busy_job ON busy_job.id = busy.job_id
                  WHERE busy_job.channel_id = j.channel_id AND busy.status = 'PUBLISHING')
            ORDER BY i.scheduled_at, i.position
            LIMIT 1
            FOR UPDATE OF i, j SKIP LOCKED
            """, nativeQuery = true)
    Optional<BulkPublishItem> lockNextDueItem(@Param("now") Instant now);

    @Query("""
            SELECT i FROM BulkPublishItem i JOIN FETCH i.job j
            WHERE j.channel.id = :channelId AND i.status = :status
            ORDER BY i.scheduledAt, i.position
            """)
    List<BulkPublishItem> findQueue(@Param("channelId") UUID channelId,
                                    @Param("status") BulkPublishItemStatus status);

    /** Latest slot in the channel's queue, or the latest bulk post that already went out. */
    @Query("""
            SELECT MAX(CASE WHEN i.status = :pending THEN i.scheduledAt ELSE i.processedAt END)
            FROM BulkPublishItem i
            WHERE i.job.channel.id = :channelId AND (i.status = :pending OR i.processedAt IS NOT NULL)
            """)
    Instant findQueueTail(@Param("channelId") UUID channelId, @Param("pending") BulkPublishItemStatus pending);

    List<BulkPublishItem> findByPostIdInAndStatusIn(Collection<UUID> postIds,
                                                    Collection<BulkPublishItemStatus> statuses);

    Optional<BulkPublishItem> findFirstByPostIdAndStatusIn(UUID postId, Collection<BulkPublishItemStatus> statuses);

    /** Moves a queued post's slot without touching its status (it may be cancelled concurrently). */
    @Modifying
    @Query("UPDATE BulkPublishItem i SET i.scheduledAt = :at WHERE i.id = :id AND i.status = :pending")
    int reschedule(@Param("id") UUID id, @Param("at") Instant at, @Param("pending") BulkPublishItemStatus pending);

    /** Heartbeat for a post being published (see BulkPublishProcessor#failStalledItems). */
    @Transactional
    @Modifying
    @Query("UPDATE BulkPublishItem i SET i.updatedAt = :now WHERE i.id = :id")
    int touch(@Param("id") UUID id, @Param("now") Instant now);

    @Modifying
    @Query(value = """
            UPDATE bulk_publish_items
            SET status = 'FAILED', error_message = :reason, updated_at = now()
            WHERE status = 'PUBLISHING' AND updated_at < :cutoff
            """, nativeQuery = true)
    int failStalled(@Param("cutoff") Instant cutoff, @Param("reason") String reason);
}
