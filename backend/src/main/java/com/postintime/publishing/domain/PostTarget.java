package com.postintime.publishing.domain;

import com.postintime.post.Post;
import com.postintime.social.PostingMode;
import com.postintime.social.SocialAccount;
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
@Table(name = "post_targets")
@Getter
@Setter
@NoArgsConstructor
public class PostTarget {

    @Id
    private UUID id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "post_id", nullable = false)
    private Post post;

    @ManyToOne(optional = false)
    @JoinColumn(name = "social_account_id", nullable = false)
    private SocialAccount socialAccount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private TargetStatus status = TargetStatus.PENDING;

    @Enumerated(EnumType.STRING)
    @Column(name = "publishing_mode", nullable = false, length = 30)
    private PostingMode publishingMode = PostingMode.MANUAL;

    @Column(name = "published_at")
    private Instant publishedAt;

    @Column(name = "external_post_id")
    private String externalPostId;

    @Column(name = "external_url")
    private String externalUrl;

    @Column(name = "error_code", length = 100)
    private String errorCode;

    @Column(name = "error_message")
    private String errorMessage;

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
