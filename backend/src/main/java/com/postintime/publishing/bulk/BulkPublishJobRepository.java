package com.postintime.publishing.bulk;

import org.springframework.data.domain.Pageable;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BulkPublishJobRepository extends JpaRepository<BulkPublishJob, UUID> {

    Optional<BulkPublishJob> findByIdAndChannelId(UUID id, UUID channelId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT j FROM BulkPublishJob j WHERE j.id = :id AND j.channel.id = :channelId")
    Optional<BulkPublishJob> lockByIdAndChannelId(@Param("id") UUID id, @Param("channelId") UUID channelId);

    List<BulkPublishJob> findByChannelIdOrderByCreatedAtDesc(UUID channelId, Pageable pageable);

    /**
     * Locks the earliest due running job. SKIP LOCKED keeps two backend instances from
     * processing the same job at once.
     */
    @Query(value = """
            SELECT * FROM bulk_publish_jobs
            WHERE status = 'RUNNING' AND next_run_at <= :now
            ORDER BY next_run_at
            LIMIT 1
            FOR UPDATE SKIP LOCKED
            """, nativeQuery = true)
    Optional<BulkPublishJob> lockNextDueJob(@Param("now") Instant now);
}
