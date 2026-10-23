package com.postintime.publishing.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.BufferingClientHttpRequestFactory;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import java.time.Duration;

@Configuration
public class WebhookClientConfig {

    /**
     * @param readTimeout how long to wait for a webhook to answer. Posting webhooks (n8n flows that
     *                    upload media to social networks) can take many minutes, so this defaults to 15.
     */
    @Bean
    public RestClient webhookRestClient(@Value("${app.webhook.read-timeout:15m}") Duration readTimeout) {
        JdkClientHttpRequestFactory jdkFactory = new JdkClientHttpRequestFactory();
        jdkFactory.setReadTimeout(readTimeout);
        // Buffer the body so Content-Length is set. Chunked multipart often drops text
        // form fields (title/caption) on receivers like n8n while still delivering the file.
        return RestClient.builder()
                .requestFactory(new BufferingClientHttpRequestFactory(jdkFactory))
                .build();
    }
}
