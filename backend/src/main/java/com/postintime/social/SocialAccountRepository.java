package com.postintime.social;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SocialAccountRepository extends JpaRepository<SocialAccount, UUID> {

    List<SocialAccount> findByChannelIdOrderByNameAsc(UUID channelId);

    Optional<SocialAccount> findByIdAndChannelId(UUID id, UUID channelId);

    List<SocialAccount> findByIdInAndChannelId(List<UUID> ids, UUID channelId);
}
