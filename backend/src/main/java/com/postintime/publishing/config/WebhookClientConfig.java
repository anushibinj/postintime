package com.postintime.publishing.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.BufferingClientHttpRequestFactory;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import java.time.Duration;

@Configuration
public class WebhookClientConfig {

    @Bean
    public RestClient webhookRestClient() {
        JdkClientHttpRequestFactory jdkFactory = new JdkClientHttpRequestFactory();
        jdkFactory.setReadTimeout(Duration.ofSeconds(30));
        // Buffer the body so Content-Length is set. Chunked multipart often drops text
        // form fields (title/caption) on receivers like n8n while still delivering the file.
        return RestClient.builder()
                .requestFactory(new BufferingClientHttpRequestFactory(jdkFactory))
                .build();
    }
}
