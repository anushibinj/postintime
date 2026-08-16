package com.postintime.publishing.publisher;

import com.postintime.publishing.domain.PublishContext;
import com.postintime.publishing.domain.PublishResult;
import com.postintime.social.Platform;
import com.postintime.social.PostingMode;
import org.springframework.stereotype.Component;

@Component
public class ManualSocialMediaPublisher implements SocialMediaPublisher {

    @Override
    public Platform platform() {
        return null;
    }

    @Override
    public boolean supports(PostingMode mode) {
        return mode == PostingMode.MANUAL;
    }

    @Override
    public PublishResult publish(PublishContext context) {
        return PublishResult.manualInstructions();
    }
}
