package com.postintime.social;

import com.postintime.channel.Channel;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "social_accounts")
@Getter
@Setter
@NoArgsConstructor
public class SocialAccount {

    @Id
    private UUID id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "channel_id", nullable = false)
    private Channel channel;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 50)
    private Platform platform;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(name = "profile_url")
    private String profileUrl;

    @Enumerated(EnumType.STRING)
    @Column(name = "posting_mode", nullable = false, length = 30)
    private PostingMode postingMode = PostingMode.MANUAL;

    @Column(name = "webhook_url")
    private String webhookUrl;

    @Enumerated(EnumType.STRING)
    @Column(name = "webhook_auth_type", nullable = false, length = 20)
    private WebhookAuthType webhookAuthType = WebhookAuthType.NONE;

    @Column(name = "webhook_username")
    private String webhookUsername;

    @Column(name = "webhook_password")
    private String webhookPassword;

    @Column(nullable = false)
    private boolean enabled = true;

    @Column(name = "provider_account_id")
    private String providerAccountId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        Instant now = Instant.now();
        createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }
}
