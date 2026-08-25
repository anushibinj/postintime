package com.postintime.publishing.publisher;

import com.postintime.media.Media;
import com.postintime.media.StorageService;
import com.postintime.post.Post;
import com.postintime.publishing.domain.PublishContext;
import com.postintime.publishing.domain.PublishResult;
import com.postintime.social.Platform;
import com.postintime.social.PostingMode;
import com.postintime.social.SocialAccount;
import com.postintime.social.WebhookAuthType;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.MultipartBodyBuilder;
import org.springframework.stereotype.Component;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

@Component
public class WebhookSocialMediaPublisher implements SocialMediaPublisher {

    private final RestClient webhookRestClient;
    private final StorageService storageService;

    public WebhookSocialMediaPublisher(@Qualifier("webhookRestClient") RestClient webhookRestClient,
                                       StorageService storageService) {
        this.webhookRestClient = webhookRestClient;
        this.storageService = storageService;
    }

    @Override
    public Platform platform() {
        return null;
    }

    @Override
    public boolean supports(PostingMode mode) {
        return mode == PostingMode.WEBHOOK;
    }

    @Override
    public PublishResult publish(PublishContext context) {
        SocialAccount account = context.socialAccount();
        String url = account.getWebhookUrl();
        if (url == null || url.isBlank()) {
            return PublishResult.failure("WEBHOOK_NOT_CONFIGURED", "Webhook URL is not configured for this account.");
        }

        Post post = context.post();
        MultipartBodyBuilder bodyBuilder = new MultipartBodyBuilder();
        // Explicit text/plain parts so receivers (e.g. n8n) always see title/caption as form fields.
        bodyBuilder.part("title", post.getTitle() == null ? "" : post.getTitle(), MediaType.TEXT_PLAIN);
        bodyBuilder.part("caption", post.getCaption() == null ? "" : post.getCaption(), MediaType.TEXT_PLAIN);

        Media media = post.getMedia();
        if (media != null) {
            try {
                byte[] bytes = storageService.download(media.getStorageKey());
                String filename = media.getOriginalFilename() == null ? "media" : media.getOriginalFilename();
                ByteArrayResource file = new ByteArrayResource(bytes) {
                    @Override
                    public String getFilename() {
                        return filename;
                    }
                };
                bodyBuilder.part("media", file)
                        .filename(filename)
                        .contentType(parseMediaType(media.getContentType()));
            } catch (Exception ex) {
                return PublishResult.failure("MEDIA_READ_FAILED", "Could not read post media for the webhook.");
            }
        }

        MultiValueMap<String, HttpEntity<?>> parts = bodyBuilder.build();
        var request = webhookRestClient.post().uri(url);
        if (account.getWebhookAuthType() == WebhookAuthType.BASIC) {
            String raw = (account.getWebhookUsername() == null ? "" : account.getWebhookUsername())
                    + ":"
                    + (account.getWebhookPassword() == null ? "" : account.getWebhookPassword());
            String encoded = Base64.getEncoder().encodeToString(raw.getBytes(StandardCharsets.UTF_8));
            request = request.header(HttpHeaders.AUTHORIZATION, "Basic " + encoded);
        }

        try {
            // Do not set Content-Type: multipart/form-data without a boundary — n8n then sees an empty body.
            request.body(parts).retrieve().toBodilessEntity();
            return PublishResult.ok();
        } catch (RestClientResponseException ex) {
            String responseBody = ex.getResponseBodyAsString();
            String detail = "Webhook returned HTTP " + ex.getStatusCode().value();
            if (responseBody != null && !responseBody.isBlank()) {
                detail = detail + ": " + responseBody.strip();
            }
            return PublishResult.failure("WEBHOOK_HTTP_ERROR", truncate(detail));
        } catch (Exception ex) {
            String message = ex.getMessage() == null ? "Webhook request failed." : ex.getMessage();
            return PublishResult.failure("WEBHOOK_UNREACHABLE", truncate(message));
        }
    }

    private MediaType parseMediaType(String contentType) {
        if (contentType == null || contentType.isBlank()) {
            return MediaType.APPLICATION_OCTET_STREAM;
        }
        try {
            return MediaType.parseMediaType(contentType);
        } catch (Exception ex) {
            return MediaType.APPLICATION_OCTET_STREAM;
        }
    }

    private String truncate(String value) {
        if (value.length() <= 2000) {
            return value;
        }
        return value.substring(0, 2000) + "…";
    }
}
