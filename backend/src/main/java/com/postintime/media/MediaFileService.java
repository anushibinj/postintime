package com.postintime.media;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.InputStreamResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

@Service
public class MediaFileService {

    private final S3Client s3Client;
    private final String bucket;
    private final String storageType;
    private final Path localRoot;

    public MediaFileService(
            S3Client s3Client,
            @Value("${app.storage.bucket}") String bucket,
            @Value("${app.storage.type:s3}") String storageType,
            @Value("${app.storage.local-path:./storage}") String localPath) {
        this.s3Client = s3Client;
        this.bucket = bucket;
        this.storageType = storageType;
        this.localRoot = Path.of(localPath);
    }

    public Resource load(String key) throws IOException {
        if ("local".equals(storageType)) {
            Path file = localRoot.resolve(key);
            if (!Files.exists(file)) {
                throw new IOException("File not found");
            }
            return new InputStreamResource(Files.newInputStream(file));
        }
        GetObjectRequest request = GetObjectRequest.builder().bucket(bucket).key(key).build();
        ResponseInputStream<GetObjectResponse> object = s3Client.getObject(request);
        return new InputStreamResource(object);
    }

    public String getContentType(String key) throws IOException {
        if ("local".equals(storageType)) {
            Path file = localRoot.resolve(key);
            String probed = Files.probeContentType(file);
            return probed != null ? probed : "application/octet-stream";
        }
        GetObjectRequest request = GetObjectRequest.builder().bucket(bucket).key(key).build();
        try (ResponseInputStream<GetObjectResponse> object = s3Client.getObject(request)) {
            String contentType = object.response().contentType();
            return contentType != null ? contentType : "application/octet-stream";
        }
    }
}
