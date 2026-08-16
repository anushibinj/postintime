package com.postintime.publishing.publisher;

import com.postintime.publishing.domain.PublishContext;
import com.postintime.publishing.domain.PublishResult;
import com.postintime.social.Platform;
import com.postintime.social.PostingMode;

public interface SocialMediaPublisher {

    Platform platform();

    boolean supports(PostingMode mode);

    PublishResult publish(PublishContext context);
}
