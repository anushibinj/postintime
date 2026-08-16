package com.postintime.publishing.domain;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PostTargetRepository extends JpaRepository<PostTarget, UUID> {

    List<PostTarget> findByPostId(UUID postId);

    Optional<PostTarget> findByIdAndPostId(UUID id, UUID postId);

    boolean existsByPostIdAndSocialAccountId(UUID postId, UUID socialAccountId);

    long countByPostIdAndStatus(UUID postId, TargetStatus status);
}
