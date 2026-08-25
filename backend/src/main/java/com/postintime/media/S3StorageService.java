package com.postintime.media;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.core.ResponseBytes;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.InputStream;
import java.net.URI;

@Service
@org.springframework.boot.autoconfigure.condition.ConditionalOnProperty(name = "app.storage.type", havingValue = "s3", matchIfMissing = true)
public class S3StorageService implements StorageService {

    private final S3Client s3Client;
    private final String bucket;
    private final String endpoint;
    private final String baseUrl;

    public S3StorageService(
            @Value("${app.storage.endpoint}") String endpoint,
            @Value("${app.storage.access-key}") String accessKey,
            @Value("${app.storage.secret-key}") String secretKey,
            @Value("${app.storage.bucket}") String bucket,
            @Value("${app.storage.region}") String region,
            @Value("${app.base-url}") String baseUrl) {
        this.endpoint = endpoint;
        this.bucket = bucket;
        this.baseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        this.s3Client = S3Client.builder()
                .endpointOverride(URI.create(endpoint))
                .region(Region.of(region))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(accessKey, secretKey)))
                .serviceConfiguration(S3Configuration.builder().pathStyleAccessEnabled(true).build())
                .build();
    }

    @Override
    public String upload(String key, InputStream inputStream, long size, String contentType) {
        PutObjectRequest request = PutObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .contentType(contentType)
                .build();
        s3Client.putObject(request, RequestBody.fromInputStream(inputStream, size));
        return key;
    }

    @Override
    public void delete(String key) {
        s3Client.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(key).build());
    }

    @Override
    public byte[] download(String key) {
        ResponseBytes<GetObjectResponse> object = s3Client.getObjectAsBytes(
                GetObjectRequest.builder().bucket(bucket).key(key).build());
        return object.asByteArray();
    }

    @Override
    public String getPublicUrl(String key) {
        return baseUrl + "/api/v1/media/files/" + key;
    }
}
