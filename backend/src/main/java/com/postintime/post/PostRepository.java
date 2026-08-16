package com.postintime.post;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface PostRepository extends JpaRepository<Post, UUID> {

    Optional<Post> findByIdAndChannelId(UUID id, UUID channelId);

    @Query("""
            SELECT p FROM Post p
            WHERE p.channel.id = :channelId
            AND (:search = '' OR LOWER(p.title) LIKE LOWER(CONCAT('%', :search, '%'))
                 OR LOWER(COALESCE(p.caption, '')) LIKE LOWER(CONCAT('%', :search, '%')))
            AND (:status IS NULL OR p.status = :status)
            """)
    Page<Post> searchPosts(@Param("channelId") UUID channelId,
                           @Param("search") String search,
                           @Param("status") PostStatus status,
                           Pageable pageable);
}
