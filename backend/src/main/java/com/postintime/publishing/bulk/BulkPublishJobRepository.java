package com.postintime.publishing.bulk;

import org.springframework.data.domain.Pageable;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BulkPublishJobRepository extends JpaRepository<BulkPublishJob, UUID> {

    Optional<BulkPublishJob> findByIdAndChannelId(UUID id, UUID channelId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT j FROM BulkPublishJob j WHERE j.id = :id AND j.channel.id = :channelId")
    Optional<BulkPublishJob> lockByIdAndChannelId(@Param("id") UUID id, @Param("channelId") UUID channelId);


    List<BulkPublishJob> findByChannelIdAndStatusOrderByCreatedAtAsc(UUID channelId, BulkPublishJobStatus status);

    List<BulkPublishJob> findByChannelIdAndStatusNotOrderByCreatedAtDesc(UUID channelId,
                                                                         BulkPublishJobStatus status,
                                                                         Pageable pageable);

    @Modifying
    @Query(value = """
            UPDATE bulk_publish_jobs j
            SET status = 'COMPLETED', updated_at = now()
            WHERE status = 'RUNNING'
              AND NOT EXISTS (SELECT 1 FROM bulk_publish_items i
                              WHERE i.job_id = j.id AND i.status IN ('PENDING', 'PUBLISHING'))
            """, nativeQuery = true)
    int completeJobsWithoutOpenItems();

    /** Locks the channel row so queue appends for one channel happen one at a time. */
    @Query(value = "SELECT id FROM channels WHERE id = :channelId FOR UPDATE", nativeQuery = true)
    UUID lockChannelQueue(@Param("channelId") UUID channelId);
}
