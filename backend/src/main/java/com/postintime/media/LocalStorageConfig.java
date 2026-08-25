package com.postintime.media;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;

@Configuration
public class LocalStorageConfig {

    @Bean
    @Primary
    @ConditionalOnProperty(name = "app.storage.type", havingValue = "local")
    public StorageService localStorageService(@Value("${app.storage.local-path:./storage}") String localPath,
                                              @Value("${app.base-url}") String baseUrl) {
        final String publicBaseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        return new StorageService() {
            private final Path root = Path.of(localPath);

            {
                try {
                    Files.createDirectories(root);
                } catch (IOException e) {
                    throw new IllegalStateException("Cannot create storage directory", e);
                }
            }

            @Override
            public String upload(String key, InputStream inputStream, long size, String contentType) {
                try {
                    Path file = root.resolve(key);
                    Files.createDirectories(file.getParent());
                    Files.copy(inputStream, file);
                    return key;
                } catch (IOException e) {
                    throw new RuntimeException(e);
                }
            }

            @Override
            public void delete(String key) {
                try {
                    Files.deleteIfExists(root.resolve(key));
                } catch (IOException e) {
                    throw new RuntimeException(e);
                }
            }

            @Override
            public byte[] download(String key) {
                try {
                    return Files.readAllBytes(root.resolve(key));
                } catch (IOException e) {
                    throw new RuntimeException(e);
                }
            }

            @Override
            public String getPublicUrl(String key) {
                return publicBaseUrl + "/api/v1/media/files/" + key;
            }
        };
    }
}
