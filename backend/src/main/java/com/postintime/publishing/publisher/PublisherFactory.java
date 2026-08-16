package com.postintime.publishing.publisher;

import com.postintime.social.PostingMode;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class PublisherFactory {

    private final List<SocialMediaPublisher> publishers;

    public PublisherFactory(List<SocialMediaPublisher> publishers) {
        this.publishers = publishers;
    }

    public SocialMediaPublisher getPublisher(PostingMode mode) {
        return publishers.stream()
                .filter(p -> p.supports(mode))
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("No publisher for mode: " + mode));
    }
}
