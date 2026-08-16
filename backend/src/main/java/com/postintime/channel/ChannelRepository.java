package com.postintime.channel;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ChannelRepository extends JpaRepository<Channel, UUID> {

    List<Channel> findByUserIdOrderByNameAsc(UUID userId);

    Optional<Channel> findByIdAndUserId(UUID id, UUID userId);

    boolean existsByUserIdAndSlug(UUID userId, String slug);

    @Query("SELECT COUNT(p) FROM com.postintime.post.Post p WHERE p.channel.id = :channelId")
    long countPostsByChannelId(UUID channelId);

    @Query("SELECT COUNT(s) FROM com.postintime.social.SocialAccount s WHERE s.channel.id = :channelId")
    long countSocialAccountsByChannelId(UUID channelId);
}
