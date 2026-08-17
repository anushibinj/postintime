package com.postintime.publishing.domain;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PostTargetRepository extends JpaRepository<PostTarget, UUID> {

    @Query("SELECT t FROM PostTarget t JOIN FETCH t.socialAccount WHERE t.post.id = :postId")
    List<PostTarget> findByPostId(@Param("postId") UUID postId);

    Optional<PostTarget> findByIdAndPostId(UUID id, UUID postId);

    boolean existsByPostIdAndSocialAccountId(UUID postId, UUID socialAccountId);

    long countByPostIdAndStatus(UUID postId, TargetStatus status);
}
