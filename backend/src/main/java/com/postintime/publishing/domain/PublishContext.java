package com.postintime.publishing.domain;

import com.postintime.post.Post;
import com.postintime.social.SocialAccount;

public record PublishContext(
        Post post,
        SocialAccount socialAccount,
        PostTarget target
) {
}
