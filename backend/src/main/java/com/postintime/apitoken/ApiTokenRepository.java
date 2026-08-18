package com.postintime.apitoken;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ApiTokenRepository extends JpaRepository<ApiToken, UUID> {

    List<ApiToken> findByUserIdOrderByCreatedAtDesc(UUID userId);

    Optional<ApiToken> findByIdAndUserId(UUID id, UUID userId);

    @Query("SELECT t FROM ApiToken t JOIN FETCH t.user WHERE t.tokenHash = :tokenHash")
    Optional<ApiToken> findByTokenHash(@Param("tokenHash") String tokenHash);
}
